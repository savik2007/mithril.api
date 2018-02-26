defmodule Mithril.Registration.API do
  import Joken
  import Ecto.{Query, Changeset}, warn: false

  alias Mithril.Repo
  alias Mithril.UserAPI.User

  @email_api Application.get_env(:mithril_api, __MODULE__)[:email_api]

  def send_email_verification(params) do
    with %Ecto.Changeset{valid?: true, changes: %{email: email}} <- validate_params(params),
         true <- email_available_for_registration?(email),
         false <- email_sent?(email),
         {:ok, jwt} <- generate_jwt(email) do
      case @email_api.send(email, jwt) do
        {:ok, _} -> :ok
        {:error, _} -> {:error, {:service_unavailable, "Cannot send email. Try later"}}
      end
    end
  end

  defp validate_params(params) do
    {%{}, %{email: :string}}
    |> cast(params, [:email])
    |> validate_format(:email, ~r/^[a-zA-Z0-9.!#$%&’*+\/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$/)
  end

  def email_available_for_registration?(email) do
    query = from(u in User, where: u.email == ^email and "" != u.tax_id)

    case Repo.one(query) do
      nil -> true
      %User{} -> {:error, {:conflict, "User with this email already exists"}}
    end
  end

  defp email_sent?(_email) do
    # ToDo: check sent email?
    false
  end

  defp generate_jwt(email) do
    secret = Confex.fetch_env!(:mithril_api, __MODULE__)[:jwt_secret]

    {:ok,
     %{email: email}
     |> token()
     |> with_signer(hs256(secret))
     |> sign()
     |> get_compact()}
  end
end
