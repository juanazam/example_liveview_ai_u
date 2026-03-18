# EctoFilters.DSL provides the `filter` macro used inside a `use EctoFilters` module.
#
# Each `filter` call declares one filter with a name, type, and options.
# At compile time the macro parses the block syntax and appends a map to the
# @filters module attribute, which EctoFilters.__before_compile__ reads to
# generate all the boilerplate (struct, changeset, queries, etc.).
#
# Example usage:
#
#   filter :status do
#     type :enum
#     field :status                        # column in the schema
#     values [:active, :inactive, :vip]
#     ui label: "Status", type: :select
#     ai_hint "One of: active, inactive, vip"
#   end
#
# Supported DSL keys:
#   type      - the filter kind (see EctoFilters.Types for all types)
#   field     - the schema column to filter on (defaults to the filter name)
#   values    - allowed values for :enum filters
#   ui        - keyword list of hints used to render the traditional filter UI
#   ai_hint   - plain-English description sent to the LLM so it knows how to
#               populate this field from natural language

defmodule EctoFilters.DSL do
  # Each `filter :name do ... end` call accumulates one entry in @filters.
  # The block is parsed at compile time into a plain map so no runtime code
  # is executed here.
  defmacro filter(name, do: block) do
    config = extract_config(block)

    quote do
      @filters %{
        name: unquote(name),
        type: unquote(config[:type] || :string_match),
        field: unquote(config[:field] || name),
        opts: unquote(Macro.escape(config[:opts] || %{}))
      }
    end
  end

  # Walk the AST of the do-block and build a config map.
  # Single-statement blocks are wrapped so they go through the same path.
  defp extract_config(block) do
    case block do
      {:__block__, _, statements} ->
        Enum.reduce(statements, %{opts: %{}}, &process_statement/2)

      statement ->
        process_statement(statement, %{opts: %{}})
    end
  end

  # Each recognised keyword maps to a key in the config map.
  # `field` and `type` are top-level; everything else lives under `opts`.

  defp process_statement({:type, _, [type]}, config) do
    Map.put(config, :type, type)
  end

  defp process_statement({:field, _, [field]}, config) do
    Map.put(config, :field, field)
  end

  defp process_statement({:values, _, [values]}, config) do
    put_in(config, [:opts, :values], values)
  end

  defp process_statement({:ui, _, [ui_opts]}, config) do
    put_in(config, [:opts, :ui], ui_opts)
  end

  defp process_statement({:ai_hint, _, [hint]}, config) do
    put_in(config, [:opts, :ai_hint], hint)
  end

  # Ignore any unrecognised AST nodes (e.g. blank lines in the block).
  defp process_statement(_, config), do: config
end
