defmodule Core.TokenAPITest do
  use Core.DataCase

  alias Core.TokenAPI
  alias Core.TokenAPI.Token
  alias Ecto.UUID
  alias MithrilScheduler.TokenAPI.Deactivator
  alias Scrivener.Page

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

    assert %Page{
             entries: list,
             page_number: 1,
             page_size: 50,
             total_entries: 1,
             total_pages: 1
           } = TokenAPI.list_tokens(%{})

    assert 1 == length(list)
    assert token.id == hd(list).id
  end

  test "get_token! returns the token with given id" do
    token = insert(:token)
    db_token = TokenAPI.get_token!(token.id)
    assert db_token.id == token.id
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
    db_token = TokenAPI.get_token!(token.id)
    assert db_token.id == token.id
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
      user1 = insert(:user)
      user2 = insert(:user)
      cid1 = UUID.generate()
      cid2 = UUID.generate()
      cid3 = UUID.generate()

      details = %{
        "scope" => "app:authorize",
        "grant_type" => "password",
        "redirect_uri" => "http://localhost"
      }

      token1 =
        insert(:token,
          user: user1,
          name: "access_token",
          details: Map.put(details, "client_id", cid1)
        )

      token2 =
        insert(:token,
          user: user1,
          name: "2fa_access_token",
          details: Map.put(details, "client_id", cid1)
        )

      token3 =
        insert(:token,
          user: user1,
          name: "access_token",
          details: Map.put(details, "client_id", cid2)
        )

      token4 =
        insert(:token,
          user: user2,
          name: "access_token",
          details: Map.put(details, "client_id", cid3)
        )

      %{user: user1, token1: token1, token2: token2, token3: token3, token4: token4}
    end

    test "every tokens by user", %{
      user: user,
      token1: token1,
      token2: token2,
      token3: token3,
      token4: token4
    } do
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
      token_ids =
        Enum.reduce(1..3, [], fn _, acc ->
          password_set_at = NaiveDateTime.add(NaiveDateTime.utc_now(), -100 * 24 * 60 * 60, :second)

          user = insert(:user, password_set_at: password_set_at)
          token = insert(:token, user: user)
          assert token.expires_at == 2_000_000_000
          [token.id | acc]
        end)

      Deactivator.deactivate_old_password_tokens()
      assert_receive :deactivated

      Enum.each(token_ids, fn id ->
        token = Repo.get(Token, id)
        assert token.expires_at <= :os.system_time(:seconds)
      end)
    end
  end

  test "user_id is validated" do
    assert {:error, changeset} = TokenAPI.create_token(%{user_id: "something"})

    assert {"has invalid format", _} = Keyword.get(changeset.errors, :user_id)
  end

  test "delete expired tokens" do
    ttl =
      Confex.fetch_env!(:mithril_scheduler, Deactivator)[:token_ttl_after_expiration] *
        (3600 * 24)

    token = insert(:token, expires_at: :os.system_time(:seconds) - ttl + 2)

    Enum.each(1..3, fn _ ->
      insert(:token, expires_at: 1_523_700_000)
      insert(:token, expires_at: :os.system_time(:seconds) - ttl)
    end)

    Deactivator.delete_expired_tokens()
    assert_receive :cleaned

    assert %Page{entries: list} = TokenAPI.list_tokens(%{})
    assert 1 == length(list)
    assert token.id == hd(list).id
  end
end
