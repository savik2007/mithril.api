defmodule Mithril.Registration.EmailVerificationTest do
  @doc false

  use Mithril.Web.ConnCase

  alias Mithril.Registration.API

  test "API.email_available_for_registration/1" do
    insert(:user, email: "test1@example.com", tax_id: "")
    insert(:user, email: "test2@example.com", tax_id: "12342345")

    assert true == API.email_available_for_registration?("test@example.com")
    assert true == API.email_available_for_registration?("test1@example.com")
    assert {:error, {:conflict, _}} = API.email_available_for_registration?("test2@example.com")
  end
end
