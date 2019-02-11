defmodule Core.AppAPITest do
  use Core.DataCase

  alias Core.AppAPI
  alias Core.AppAPI.App
  alias Scrivener.Page

  @create_attrs %{scope: "some scope"}
  @update_attrs %{scope: "some updated scope"}
  @invalid_attrs %{scope: nil}

  test "list_apps/1 returns all apps" do
    app = insert(:app)
    %Page{entries: apps} = AppAPI.list_apps(%{"user_id" => app.user_id})

    schema =
      "specs/json_schemas/apps.json"
      |> File.read!()
      |> Poison.decode!()

    assert length(apps) == 1
    assert :ok = NExJsonSchema.Validator.validate(schema, %{data: apps})
  end

  test "get_app! returns the app with given id" do
    app = insert(:app)

    schema =
      "specs/json_schemas/app.json"
      |> File.read!()
      |> Poison.decode!()

    assert :ok =
             NExJsonSchema.Validator.validate(
               schema,
               app.id |> AppAPI.get_app!() |> Map.from_struct()
             )
  end

  test "create_app/1 with valid data creates a app" do
    user = insert(:user)
    client = insert(:client)

    attrs = Map.merge(@create_attrs, %{user_id: user.id, client_id: client.id})
    assert {:ok, %App{} = app} = AppAPI.create_app(attrs)
    assert app.scope == "some scope"
  end

  test "create_app/1 with invalid data returns error changeset" do
    assert {:error, %Ecto.Changeset{}} = AppAPI.create_app(@invalid_attrs)
  end

  test "update_app/2 with valid data updates the app" do
    app = insert(:app)
    assert {:ok, app} = AppAPI.update_app(app, @update_attrs)
    assert %App{} = app

    schema =
      "specs/json_schemas/app.json"
      |> File.read!()
      |> Poison.decode!()

    assert :ok =
             NExJsonSchema.Validator.validate(
               schema,
               app.id |> AppAPI.get_app!() |> Map.from_struct()
             )

    assert app.scope == "some updated scope"
  end

  test "update_app/2 with invalid data returns error changeset" do
    app = insert(:app)

    assert {:error, %Ecto.Changeset{}} = AppAPI.update_app(app, @invalid_attrs)
    db_app = AppAPI.get_app!(app.id)
    assert db_app.scope == app.scope
  end

  test "delete_app/1 deletes the app" do
    app = insert(:app)
    assert {:ok, _} = AppAPI.delete_app(app)
    assert_raise Ecto.NoResultsError, fn -> AppAPI.get_app!(app.id) end
  end

  test "change_app/1 returns a app changeset" do
    app = insert(:app)
    assert %Ecto.Changeset{} = AppAPI.change_app(app)
  end
end
