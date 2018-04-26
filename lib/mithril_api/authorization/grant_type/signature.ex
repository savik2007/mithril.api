defmodule Mithril.Authorization.GrantType.Signature do
  @moduledoc false

  import Ecto.{Query, Changeset}, warn: false
  import Mithril.Authorization.GrantType

  alias Mithril.{UserAPI, ClientAPI, TokenAPI, Error, Guardian}
  alias Mithril.Ecto.Base64
  alias Mithril.UserAPI.User
  alias Mithril.ClientAPI.Client

  require Logger

  @mpi_api Application.get_env(:mithril_api, :api_resolvers)[:mpi]
  @signature_api Application.get_env(:mithril_api, :api_resolvers)[:digital_signature]

  @aud_login Guardian.get_aud(:login)
  @person_inactive "INACTIVE"
  @ehealth_cabinet_client_id "30074b6e-fbab-4dc1-9d37-88c21dab1847"

  def authorize(attrs) do
    with %Ecto.Changeset{valid?: true} <- changeset(attrs),
         {:ok, %{"data" => %{"content" => content, "signer" => signer}}} <-
           @signature_api.decode_and_validate(attrs["signed_content"], attrs["signed_content_encoding"], attrs),
         :ok <- validate_content_jwt(content),
         {:ok, tax_id} <- validate_signer_tax_id(signer),
         client <- ClientAPI.get_client_with_type(attrs["client_id"]),
         :ok <- ClientAPI.validate_client_allowed_grant_types(client, "digital_signature"),
         :ok <- ClientAPI.validate_client_allowed_scope(client, attrs["scope"]),
         user <- UserAPI.get_user_by(tax_id: tax_id),
         {:ok, user} <- validate_user(user),
         {:ok, person} <- get_person(user.person_id),
         :ok <- check_person_status(person),
         :ok <- validate_person_tax_id(person, tax_id),
         {:ok, scope} <- prepare_scope_by_client(client, attrs["scope"]),
         {:ok, token} <- create_access_token(user, client, scope),
         {_, nil} <- TokenAPI.deactivate_old_tokens(token) do
      {:ok, %{token: token, urgent: %{next_step: map_next_step(token)}}}
    end
  end

  defp changeset(attrs) do
    types = %{signed_content: Base64, signed_content_encoding: :string, client_id: Ecto.UUID, scope: :string}

    {%{}, types}
    |> cast(attrs, Map.keys(types))
    |> validate_required(Map.keys(types))
    |> validate_inclusion(:signed_content_encoding, ["base64"])
  end

  defp validate_content_jwt(%{"jwt" => jwt}) do
    case Guardian.decode_and_verify(jwt) do
      {:ok, %{"nonce" => _, "aud" => @aud_login}} -> :ok
      _ -> Error.jwt_invalid("JWT is invalid.")
    end
  end

  defp validate_content_jwt(_), do: Error.jwt_invalid("Signed content does not contain field jwt.")

  defp validate_signer_tax_id(%{"drfo" => tax_id}) when is_binary(tax_id) and byte_size(tax_id) > 0, do: {:ok, tax_id}
  defp validate_signer_tax_id(_), do: {:error, {:"422", "Digital signature signer does not contain drfo."}}

  def validate_user(%User{is_blocked: false, person_id: id} = user) when is_binary(id) and byte_size(id) > 0 do
    {:ok, user}
  end

  def validate_user(%User{is_blocked: true}), do: Error.user_blocked("User blocked.")
  def validate_user(_), do: {:error, {:access_denied, "Person with tax id from digital signature not found."}}

  defp get_person(person_id) do
    case @mpi_api.person(person_id) do
      {:ok, %{"data" => person}} -> {:ok, person}
      _ -> {:error, {:access_denied, "Person not found."}}
    end
  end

  defp check_person_status(%{"status" => @person_inactive}), do: {:error, {:access_denied, "Person not found."}}
  defp check_person_status(_), do: :ok

  defp validate_person_tax_id(%{"tax_id" => person_tax_id}, tax_id) when person_tax_id == tax_id do
    :ok
  end

  defp validate_person_tax_id(%{"id" => person_id}, _) do
    Logger.error("EDRPOU from Digital Signature not matched with tax_id from MPI person. Person ID #{person_id}")
    Error.tax_id_invalid("Tax id not matched with MPI person.")
  end

  defp create_access_token(%User{} = user, %Client{id: @ehealth_cabinet_client_id} = client, scope) do
    {:ok, refresh_token} =
      Mithril.TokenAPI.create_refresh_token(%{
        user_id: user.id,
        details: %{
          "grant_type" => "authorize_2fa_access_token",
          "client_id" => client.id,
          "scope" => ""
        }
      })

    TokenAPI.create_access_token(%{
      user_id: user.id,
      details: %{
        "grant_type" => "digital_signature",
        "client_id" => client.id,
        "scope" => scope,
        "redirect_uri" => client.redirect_uri,
        "refresh_token" => refresh_token.value
      }
    })
  end

  defp create_access_token(%User{} = user, client, scope) do
    data = %{
      user_id: user.id,
      details: %{
        "grant_type" => "digital_signature",
        "client_id" => client.id,
        "scope" => scope,
        "redirect_uri" => client.redirect_uri
      }
    }

    Mithril.TokenAPI.create_access_token(data)
  end
end
