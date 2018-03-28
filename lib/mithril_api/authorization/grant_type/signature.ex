defmodule Mithril.Authorization.GrantType.Signature do
  @moduledoc false

  import Ecto.{Query, Changeset}, warn: false

  import Mithril.Authorization.GrantType.Password,
    only: [validate_client: 2, next_step: 1, validate_token_scope_by_client: 2]

  alias Mithril.{UserAPI, ClientAPI, TokenAPI, Error, Guardian}
  alias Mithril.Ecto.Base64
  alias Mithril.UserAPI.User

  require Logger

  @mpi_api Application.get_env(:mithril_api, :api_resolvers)[:mpi]
  @signature_api Application.get_env(:mithril_api, :api_resolvers)[:digital_signature]

  def authorize(attrs) do
    with %Ecto.Changeset{valid?: true} <- changeset(attrs),
         {:ok, %{"data" => %{"content" => content, "signer" => signer}}} <-
           @signature_api.decode_and_validate(attrs["signed_content"], attrs["signed_content_encoding"]),
         {:ok, _jwt} <- validate_content_jwt(content),
         {:ok, tax_id} <- validate_signer_tax_id(signer),
         client <- ClientAPI.get_client_with_type(attrs["client_id"]),
         :ok <- validate_client(client, "digital_signature"),
         :ok <- validate_token_scope_by_client(client.client_type.scope, attrs["scope"]),
         user <- UserAPI.get_user_by(tax_id: tax_id),
         {:ok, user} <- validate_user(user),
         {:ok, %{"data" => person}} <- @mpi_api.person(user.person_id),
         :ok <- validate_person_tax_id(person, tax_id),
         {:ok, token} <- create_access_token(user, client, attrs["scope"]),
         {_, nil} <- TokenAPI.deactivate_old_tokens(token) do
      {:ok, %{token: token, urgent: %{next_step: next_step(:request_apps)}}}
    end
  end

  defp changeset(attrs) do
    types = %{signed_content: Base64, signed_content_encoding: :string, client_id: :string, scope: :string}

    {%{}, types}
    |> cast(attrs, Map.keys(types))
    |> validate_required(Map.keys(types))
    |> validate_inclusion(:signed_content_encoding, ["base64"])
  end

  defp validate_content_jwt(%{"jwt" => jwt}), do: Guardian.decode_and_verify(jwt)
  defp validate_content_jwt(_)

  def validate_user(%User{is_blocked: false} = user), do: {:ok, user}
  def validate_user(%User{is_blocked: true}), do: Error.user_blocked("User blocked.")
  def validate_user(_), do: {:error, {:access_denied, "Person with tax id from digital signature not found."}}

  defp validate_signer_tax_id(%{"drfo" => tax_id}), do: {:ok, tax_id}
  defp validate_signer_tax_id(_), do: {:error, {:"422", "Digital signature signer does not contain drfou"}}

  defp validate_person_tax_id(%{"tax_id" => person_tax_id}, tax_id) when person_tax_id == tax_id do
    :ok
  end

  defp validate_person_tax_id(%{"id" => person_id}, _) do
    Logger.error("EDRPOU from Digital Signature not matched with tax_id from MPI person. Person ID #{person_id}")
    Error.tax_id_invalid("Tax id not matched with MPI person")
  end

  defp create_access_token(%User{} = user, client, scope) do
    data = %{
      user_id: user.id,
      details: %{
        "grant_type" => "password",
        "client_id" => client.id,
        "scope" => scope,
        "redirect_uri" => client.redirect_uri
      }
    }

    Mithril.TokenAPI.create_access_token(data)
  end
end
