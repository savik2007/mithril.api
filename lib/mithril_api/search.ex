defmodule Mithril.Search do
  @moduledoc """
  Search implementation
  """

  defmacro __using__(_) do
    quote do
      import Ecto.{Query, Changeset}, warn: false

      alias Mithril.Paging
      alias Mithril.Repo

      def set_like_attributes(%Ecto.Changeset{valid?: false} = changeset, _like_fields), do: changeset

      def set_like_attributes(%Ecto.Changeset{valid?: true, changes: changes} = changeset, like_fields) do
        Enum.reduce(changes, changeset, fn {key, value}, changeset ->
          case key in like_fields do
            true -> put_change(changeset, key, {value, :like})
            _ -> changeset
          end
        end)
      end

      def search(%Ecto.Changeset{valid?: true, changes: changes}, search_params, entity) do
        entity
        |> get_search_query(changes)
        |> Repo.paginate(search_params)
      end

      def search(%Ecto.Changeset{valid?: false} = changeset, _search_params, _entity) do
        {:error, changeset}
      end

      def get_search_query(entity, changes) when map_size(changes) > 0 do
        params = Enum.filter(changes, fn {key, value} -> !is_tuple(value) end)

        q = from(e in entity, where: ^params)

        Enum.reduce(changes, q, fn
          {key, {value, :like}}, query ->
            where(query, [r], ilike(field(r, ^key), ^("%" <> value <> "%")))

          {key, {value, :in}}, query ->
            where(query, [r], field(r, ^key) in ^value)

          {key, {value, :intersect}}, query ->
            where(query, [r], fragment("string_to_array(?, ' ') && ?", field(r, ^key), ^value))

          _, query ->
            query
        end)
      end

      def get_search_query(entity, _changes), do: from(e in entity)

      defoverridable get_search_query: 2
    end
  end
end
