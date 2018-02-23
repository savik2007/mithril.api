defmodule Mithril.TokenAPITest do
  use Mithril.DataCase

  alias Mithril.TokenAPI
  alias Mithril.TokenAPI.Token
  alias Scrivener.Page
  alias Ecto.UUID

  @create_attrs %{
    details: %{},
    expires_at: 42,
    name: "some name",
    value: "some value"
  }

  @update_attrs %{
    details: %{},
    expires_at: 43,
    name: "some updated name",
    value: "some updated value"
  }

  @invalid_attrs %{
    details: nil,
    expires_at: nil,
    name: nil,
    value: nil
  }

  test "list_tokens/1 returns all tokens" do
    token = insert(:token)

    assert TokenAPI.list_tokens(%{}) == %Page{
             entries: [token],
             page_number: 1,
             page_size: 50,
             total_entries: 1,
             total_pages: 1
           }
  end

  test "get_token! returns the token with given id" do
    token = insert(:token)
    assert TokenAPI.get_token!(token.id) == token
  end

  test "create_token/1 with valid data creates a token" do
    user = insert(:user)

    assert {:ok, %Token{} = token} = TokenAPI.create_token(Map.put_new(@create_attrs, :user_id, user.id))
    assert token.details == %{}
    assert token.expires_at == 42
    assert token.name == "some name"
    assert token.value == "some value"
  end

  test "create_token/1 with invalid data returns error changeset" do
    assert {:error, %Ecto.Changeset{}} = TokenAPI.create_token(@invalid_attrs)
  end

  test "create_token/1 with duplicated user_id" do
    user = insert(:user)
    assert {:ok, %Token{}} = TokenAPI.create_token(Map.put_new(@create_attrs, :user_id, user.id))
    assert {:error, %Ecto.Changeset{}} = TokenAPI.create_token(Map.put_new(@create_attrs, :user_id, user.id))
  end

  test "create_token/1 with invalid user_id" do
    assert {:error, %Ecto.Changeset{}} = TokenAPI.create_token(Map.put_new(@create_attrs, :user_id, UUID.generate()))
  end

  test "update_token/2 with valid data updates the token" do
    token = insert(:token)
    assert {:ok, token} = TokenAPI.update_token(token, @update_attrs)
    assert %Token{} = token
    assert token.details == %{}
    assert token.expires_at == 43
    assert token.name == "some updated name"
    assert token.value == "some updated value"
  end

  test "update_token/2 with invalid data returns error changeset" do
    token = insert(:token)
    assert {:error, %Ecto.Changeset{}} = TokenAPI.update_token(token, @invalid_attrs)
    assert token == TokenAPI.get_token!(token.id)
  end

  test "delete_token/1 deletes the token" do
    token = insert(:token)
    assert {:ok, %Token{}} = TokenAPI.delete_token(token)
    assert_raise Ecto.NoResultsError, fn -> TokenAPI.get_token!(token.id) end
  end

  test "change_token/1 returns a token changeset" do
    token = insert(:token)
    assert %Ecto.Changeset{} = TokenAPI.change_token(token)
  end

  describe "deactivate tokens" do
    setup do
      %{id: user_id1} = user1 = insert(:user)
      %{id: user_id2} = insert(:user)
      cid1 = UUID.generate()
      cid2 = UUID.generate()
      cid3 = UUID.generate()

      details = %{
        "scope" => "app:authorize",
        "grant_type" => "password",
        "redirect_uri" => "http://localhost"
      }

      token1 = insert(:token, user_id: user_id1, name: "access_token", details: Map.put(details, "client_id", cid1))
      token2 = insert(:token, user_id: user_id1, name: "2fa_access_token", details: Map.put(details, "client_id", cid1))
      token3 = insert(:token, user_id: user_id1, name: "access_token", details: Map.put(details, "client_id", cid2))
      token4 = insert(:token, user_id: user_id2, name: "access_token", details: Map.put(details, "client_id", cid3))

      %{user: user1, token1: token1, token2: token2, token3: token3, token4: token4}
    end

    test "every tokens by user", %{user: user, token1: token1, token2: token2, token3: token3, token4: token4} do
      assert {3, nil} = TokenAPI.deactivate_tokens_by_user(user)

      assert token1.id
             |> TokenAPI.get_token!()
             |> TokenAPI.expired?()

      assert token2.id
             |> TokenAPI.get_token!()
             |> TokenAPI.expired?()

      assert token3.id
             |> TokenAPI.get_token!()
             |> TokenAPI.expired?()

      # token for different user
      refute token4.id
             |> TokenAPI.get_token!()
             |> TokenAPI.expired?()
    end

    test "by user and client", %{token1: token1, token2: token2, token3: token3, token4: token4} do
      assert {1, nil} = TokenAPI.deactivate_old_tokens(token1)

      # current token not expired
      refute token1.id
             |> TokenAPI.get_token!()
             |> TokenAPI.expired?()

      # old user token expired
      assert token2.id
             |> TokenAPI.get_token!()
             |> TokenAPI.expired?()

      # different client
      refute token3.id
             |> TokenAPI.get_token!()
             |> TokenAPI.expired?()

      # different user
      refute token4.id
             |> TokenAPI.get_token!()
             |> TokenAPI.expired?()
    end

    test "deactivate_old_password_tokens" do
      %{id: user_id} =
        insert(:user, password_set_at: NaiveDateTime.add(NaiveDateTime.utc_now(), -100 * 24 * 60 * 60, :second))

      token = insert(:token, user_id: user_id)
      assert token.expires_at == 2_000_000_000
      TokenAPI.deactivate_old_password_tokens()
      token = Repo.get(Token, token.id)
      assert token.expires_at <= :os.system_time(:seconds)
    end
  end

  test "user_id is validated" do
    assert {:error, changeset} = TokenAPI.create_token(%{user_id: "something"})

    assert {"has invalid format", _} = Keyword.get(changeset.errors, :user_id)
  end
end
