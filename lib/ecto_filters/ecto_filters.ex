# EctoFilters is a compile-time code generator for filter modules.
#
# A filter module is defined with:
#
#   defmodule MyApp.Filters do
#     use EctoFilters, schema: MyApp.MySchema
#
#     filter :status do
#       type :enum
#       values [:active, :inactive]
#       ...
#     end
#   end
#
# From those filter declarations, EctoFilters generates:
#
#   MyApp.Filters.Filter          - embedded Ecto schema holding filter values
#   MyApp.Filters.AISchema        - Instructor-backed schema for LLM parsing
#   changeset/2, new/0            - cast and validate filter params from a form
#   apply/2                       - build a composable Ecto query from a filter
#   ui_metadata/0                 - map of UI hints for rendering filter inputs
#   parse_intent/1                - translate natural language → Filter struct
#   list/3, count/3               - convenience wrappers around apply + Repo
#
# The actual per-type logic (field definitions, validations, query helpers,
# metadata) lives in EctoFilters.Types.

defmodule EctoFilters do
  # When a module calls `use EctoFilters, schema: SomeSchema`:
  #   1. Import the DSL so `filter :name do ... end` is available.
  #   2. Register the @filters accumulator that each `filter` call appends to.
  #   3. Store the target schema module for future reference.
  #   4. Register a before_compile hook so generation runs after all filters
  #      have been declared.
  defmacro __using__(opts) do
    schema = Keyword.fetch!(opts, :schema)

    quote do
      import EctoFilters.DSL

      Module.register_attribute(__MODULE__, :filters, accumulate: true)
      Module.register_attribute(__MODULE__, :schema_module, [])
      Module.put_attribute(__MODULE__, :schema_module, unquote(schema))

      @before_compile EctoFilters
    end
  end

  # After all `filter` declarations have been evaluated, generate all the
  # boilerplate by injecting quoted code into the calling module.
  defmacro __before_compile__(env) do
    filters = Module.get_attribute(env.module, :filters)
    schema_module = Module.get_attribute(env.module, :schema_module)

    quote do
      unquote(generate_filter_struct(filters))
      unquote(generate_changeset_function(filters))
      unquote(generate_query_functions(filters, schema_module))
      unquote(generate_ui_metadata(filters))
      unquote(generate_ai_schema(filters))
      unquote(generate_public_api())
    end
  end

  # ── Code generators ──────────────────────────────────────────────────────

  # Generates the `Filter` embedded schema.
  # Each filter type contributes one or more fields (e.g. :integer_range adds
  # `name_min` and `name_max`). The schema has no primary key because it is
  # only used in-memory, never persisted.
  defp generate_filter_struct(filters) do
    fields =
      Enum.flat_map(filters, fn filter ->
        EctoFilters.Types.schema_fields(filter[:type], filter[:name], filter[:opts])
      end)

    quote do
      defmodule Filter do
        use Ecto.Schema
        import Ecto.Changeset

        @primary_key false
        embedded_schema do
          (unquote_splicing(fields))
        end
      end
    end
  end

  # Generates `changeset/2` and `new/0`.
  #
  # `changeset/2` casts all declared filter fields from form params and runs
  # any type-specific validations (e.g. min ≤ max for integer ranges).
  # Validations are collected as anonymous functions so they can be spliced
  # into the generated function body as sequential `changeset = fn.(changeset)`
  # calls.
  defp generate_changeset_function(filters) do
    validations =
      Enum.flat_map(filters, fn filter ->
        EctoFilters.Types.validations(filter[:type], filter[:name], filter[:opts])
      end)

    field_names =
      Enum.flat_map(filters, fn f ->
        EctoFilters.Types.field_names(f[:type], f[:name], f[:opts])
      end)

    validation_calls =
      Enum.map(validations, fn validation_fn ->
        quote do
          changeset = unquote(validation_fn).(changeset)
        end
      end)

    quote do
      import Ecto.Changeset

      def changeset(filter, attrs) do
        changeset = cast(filter, attrs, unquote(field_names))
        unquote_splicing(validation_calls)
        changeset
      end

      def new, do: %Filter{}

      # Shared helper used by :integer_range validations to ensure min ≤ max.
      defp validate_range(changeset, min_field, max_field) do
        min_val = get_field(changeset, min_field)
        max_val = get_field(changeset, max_field)

        case {min_val, max_val} do
          {min, max} when is_integer(min) and is_integer(max) and min > max ->
            add_error(changeset, max_field, "must be greater than minimum")

          _ ->
            changeset
        end
      end
    end
  end

  # Generates `apply/2`, which threads a Filter struct through a chain of
  # private query helpers to produce a composable Ecto query.
  #
  # Two things are generated:
  #   1. `apply_body` - one `query = apply_*(query, ...)` call per filter,
  #      with field names and filter struct field names resolved at compile time.
  #   2. `helpers` - the private `defp apply_*` functions, deduplicated by type
  #      so the same helper is not defined twice when multiple filters share
  #      the same type (e.g. two :days_range filters).
  defp generate_query_functions(filters, _schema_module) do
    helpers =
      filters
      |> Enum.map(& &1[:type])
      |> Enum.uniq()
      |> Enum.flat_map(fn type ->
        EctoFilters.Types.query_helpers(type, nil, %{})
      end)

    apply_body =
      filters
      |> Enum.map(fn filter ->
        # `field_name` is the actual database column; it may differ from the
        # filter name (e.g. filter :last_order, field :last_order_at).
        case filter[:type] do
          :integer_range ->
            field_name = filter[:field] || filter[:name]
            min_field = :"#{filter[:name]}_min"
            max_field = :"#{filter[:name]}_max"

            quote do
              query =
                apply_integer_range(
                  query,
                  filter.unquote(min_field),
                  filter.unquote(max_field),
                  unquote(field_name)
                )
            end

          :enum ->
            field_name = filter[:field] || filter[:name]

            quote do
              query = apply_enum(query, filter.unquote(filter[:name]), unquote(field_name))
            end

          :string_match ->
            field_name = filter[:field] || filter[:name]

            quote do
              query =
                apply_string_match(query, filter.unquote(filter[:name]), unquote(field_name))
            end

          :boolean ->
            field_name = filter[:field] || filter[:name]

            quote do
              query = apply_boolean(query, filter.unquote(filter[:name]), unquote(field_name))
            end

          :days_ago ->
            field_name = filter[:field] || filter[:name]
            days_field = :"#{filter[:name]}_before_days"

            quote do
              query = apply_days_ago(query, filter.unquote(days_field), unquote(field_name))
            end

          :days_range ->
            field_name = filter[:field] || filter[:name]
            before_field = :"#{filter[:name]}_before_days"
            after_field = :"#{filter[:name]}_after_days"

            quote do
              query =
                apply_days_range(
                  query,
                  filter.unquote(before_field),
                  filter.unquote(after_field),
                  unquote(field_name)
                )
            end
        end
      end)

    quote do
      import Ecto.Query, warn: false

      def apply(query, %Filter{} = filter) do
        unquote_splicing(apply_body)
        query
      end

      unquote_splicing(helpers)
    end
  end

  # Generates `ui_metadata/0`, which returns a map of rendering hints keyed
  # by filter name. The traditional filter UI reads this to know what kind of
  # input to render for each filter (select, number, text, etc.).
  defp generate_ui_metadata(filters) do
    metadata_map =
      Enum.into(filters, %{}, fn filter ->
        {filter[:name],
         EctoFilters.Types.ui_metadata(filter[:type], filter[:name], filter[:opts])}
      end)

    quote do
      def ui_metadata do
        unquote(Macro.escape(metadata_map))
      end
    end
  end

  # Generates the `AISchema` submodule and `parse_intent/1`.
  #
  # `AISchema` is an Instructor-backed Ecto schema with the same fields as
  # `Filter`. The `@llm_doc` attribute is built from each filter's `ai_hint`
  # so the LLM knows what values each field expects.
  #
  # `parse_intent/1` sends natural language text to the LLM, receives a
  # validated `AISchema` struct back (Instructor handles retries and schema
  # enforcement), then runs it through the regular `changeset/2` as a second
  # validation pass before returning a `Filter` struct.
  #
  # This means AI-generated filters go through exactly the same validation
  # path as manually entered filters.
  defp generate_ai_schema(filters) do
    ai_fields =
      Enum.flat_map(filters, fn filter ->
        EctoFilters.Types.schema_fields(filter[:type], filter[:name], filter[:opts])
      end)

    ai_doc =
      filters
      |> Enum.map(fn filter ->
        EctoFilters.Types.ai_hint(filter[:type], filter[:name], filter[:opts])
      end)
      |> Enum.filter(& &1)
      |> Enum.join("\n")

    quote do
      defmodule AISchema do
        use Ecto.Schema
        use Instructor

        @llm_doc unquote("Filter parameters extracted from natural language:\n\n" <> ai_doc)

        @primary_key false
        embedded_schema do
          (unquote_splicing(ai_fields))
        end
      end

      def parse_intent(text) when is_binary(text) and text != "" do
        case Instructor.chat_completion(
               model: "gpt-4o-mini",
               max_retries: 3,
               response_model: AISchema,
               messages: [
                 %{
                   role: "system",
                   content: """
                   You extract filter parameters from natural language queries. Follow these rules exactly:

                   CRITICAL RULES:
                   1. Only set fields that are EXPLICITLY mentioned in the request. Leave everything else null.
                   2. Do NOT assume or infer values that are not stated.

                   SPEND DIRECTION (very important):
                   - "spent MORE than X" / "spent at least X" / "high spenders" → total_spend_min (NOT total_spend_max)
                   - "spent LESS than X" / "spent at most X" / "low spenders" → total_spend_max (NOT total_spend_min)
                   - Convert dollar amounts to cents (multiply by 100). e.g. $500 → 50000
                   """
                 },
                 %{role: "user", content: text}
               ]
             ) do
          {:ok, ai_response} ->
            # Strip nil and "null" string values so only fields the LLM actually
            # populated are passed to the changeset.
            filter_params =
              ai_response
              |> Map.from_struct()
              |> Map.reject(fn {_, v} -> is_nil(v) or v == "null" end)

            case changeset(%Filter{}, filter_params) do
              %{valid?: true} = changeset ->
                {:ok, Ecto.Changeset.apply_changes(changeset)}

              changeset ->
                {:error, "Invalid filter parameters: #{inspect(changeset.errors)}"}
            end

          {:error, reason} ->
            {:error, "Failed to parse request: #{inspect(reason)}"}
        end
      end

      def parse_intent(""), do: {:error, "Empty request"}
      def parse_intent(nil), do: {:error, "Empty request"}
    end
  end

  # Generates `list/3` and `count/3` as thin convenience wrappers so callers
  # don't have to pipe through `apply` and `Repo` manually.
  defp generate_public_api do
    quote do
      def list(query_module, repo, filter \\ new()) do
        query_module
        |> apply(filter)
        |> repo.all()
      end

      def count(query_module, repo, filter \\ new()) do
        query_module
        |> apply(filter)
        |> repo.aggregate(:count, :id)
      end
    end
  end
end
