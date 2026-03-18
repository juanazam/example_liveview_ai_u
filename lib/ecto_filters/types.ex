# EctoFilters.Types defines the behaviour of each filter type.
#
# Every type implements six concerns, each as a separate function:
#
#   schema_fields/3   - Ecto field definitions injected into Filter and AISchema
#   field_names/3     - atom list used by Ecto.Changeset.cast/3
#   validations/3     - anonymous-function AST nodes run inside changeset/2
#   query_helpers/3   - private defp functions injected into the filter module;
#                       deduplicated by type so they are defined only once even
#                       when multiple filters share the same type
#   ui_metadata/3     - map of hints for rendering traditional filter inputs
#   ai_hint/3         - plain-English field description appended to @llm_doc
#
# ── Supported types ──────────────────────────────────────────────────────────
#
#   :integer_range  - generates name_min / name_max integer fields
#                     e.g. filter :total_spend → total_spend_min, total_spend_max
#
#   :enum           - single field constrained to a list of atom values
#                     e.g. filter :status, values: [:active, :inactive]
#
#   :string_match   - exact string equality filter
#                     e.g. filter :country
#
#   :boolean        - true/false field
#                     e.g. filter :has_open_support_ticket
#
#   :days_ago       - single "before" days field: event happened > N days ago
#                     e.g. filter :last_order → last_order_before_days
#
#   :days_range     - both "before" and "after" days fields
#                     before: event happened > N days ago (older than)
#                     after:  event happened < N days ago (more recent than)
#                     e.g. filter :last_order → last_order_before_days,
#                                               last_order_after_days

defmodule EctoFilters.Types do
  import Ecto.Changeset
  import Ecto.Query

  # ── schema_fields ─────────────────────────────────────────────────────────
  # Returns quoted `field(...)` expressions to be spliced into an
  # `embedded_schema do ... end` block.

  def schema_fields(:integer_range, name, _opts) do
    [
      quote(do: field(unquote(:"#{name}_min"), :integer)),
      quote(do: field(unquote(:"#{name}_max"), :integer))
    ]
  end

  def schema_fields(:enum, name, opts) do
    values = Map.get(opts, :values, [])
    [quote(do: field(unquote(name), Ecto.Enum, values: unquote(values)))]
  end

  def schema_fields(:string_match, name, _opts) do
    [quote(do: field(unquote(name), :string))]
  end

  def schema_fields(:boolean, name, _opts) do
    [quote(do: field(unquote(name), :boolean))]
  end

  def schema_fields(:days_ago, name, _opts) do
    [quote(do: field(unquote(:"#{name}_before_days"), :integer))]
  end

  def schema_fields(:days_range, name, _opts) do
    [
      quote(do: field(unquote(:"#{name}_before_days"), :integer)),
      quote(do: field(unquote(:"#{name}_after_days"), :integer))
    ]
  end

  # ── field_names ───────────────────────────────────────────────────────────
  # Returns the atom list passed to Ecto.Changeset.cast/3 so only the
  # declared filter fields are cast from incoming params.

  def field_names(:integer_range, name, _opts), do: [:"#{name}_min", :"#{name}_max"]
  def field_names(:enum, name, _opts), do: [name]
  def field_names(:string_match, name, _opts), do: [name]
  def field_names(:boolean, name, _opts), do: [name]
  def field_names(:days_ago, name, _opts), do: [:"#{name}_before_days"]
  def field_names(:days_range, name, _opts), do: [:"#{name}_before_days", :"#{name}_after_days"]

  # ── validations ───────────────────────────────────────────────────────────
  # Returns a list of quoted anonymous functions, each accepting and returning
  # a changeset. They are called sequentially inside the generated changeset/2.

  def validations(:integer_range, name, _opts) do
    min_field = :"#{name}_min"
    max_field = :"#{name}_max"

    [
      quote do
        fn cs -> validate_number(cs, unquote(min_field), greater_than_or_equal_to: 0) end
      end,
      quote do
        fn cs -> validate_number(cs, unquote(max_field), greater_than_or_equal_to: 0) end
      end,
      # validate_range/3 is generated in the changeset function by EctoFilters
      quote do
        fn cs -> validate_range(cs, unquote(min_field), unquote(max_field)) end
      end
    ]
  end

  def validations(:days_ago, name, _opts) do
    field = :"#{name}_before_days"

    [
      quote do
        fn cs -> validate_number(cs, unquote(field), greater_than: 0) end
      end
    ]
  end

  def validations(:days_range, name, _opts) do
    before_field = :"#{name}_before_days"
    after_field = :"#{name}_after_days"

    [
      quote do
        fn cs -> validate_number(cs, unquote(before_field), greater_than: 0) end
      end,
      quote do
        fn cs -> validate_number(cs, unquote(after_field), greater_than: 0) end
      end
    ]
  end

  def validations(_type, _name, _opts), do: []

  # ── query_helpers ─────────────────────────────────────────────────────────
  # Returns quoted `defp` blocks that are injected into the filter module.
  # Each helper is nil-safe: passing nil for a filter value skips that clause.
  # Helpers are deduplicated by type in EctoFilters.generate_query_functions so
  # they are only defined once per module regardless of how many filters share
  # the same type.

  def query_helpers(:integer_range, _name, _opts) do
    [
      quote do
        defp apply_integer_range(query, nil, nil, _field), do: query

        defp apply_integer_range(query, min_val, max_val, field) do
          query = if min_val, do: where(query, [c], field(c, ^field) >= ^min_val), else: query
          if max_val, do: where(query, [c], field(c, ^field) <= ^max_val), else: query
        end
      end
    ]
  end

  def query_helpers(:enum, _name, _opts) do
    [
      quote do
        defp apply_enum(query, nil, _field), do: query

        defp apply_enum(query, value, field) do
          where(query, [c], field(c, ^field) == ^value)
        end
      end
    ]
  end

  def query_helpers(:string_match, _name, _opts) do
    [
      quote do
        defp apply_string_match(query, nil, _field), do: query
        # Empty string from a form input is treated as "no filter"
        defp apply_string_match(query, "", _field), do: query

        defp apply_string_match(query, value, field) when is_binary(value) do
          where(query, [c], field(c, ^field) == ^value)
        end
      end
    ]
  end

  def query_helpers(:boolean, _name, _opts) do
    [
      quote do
        defp apply_boolean(query, nil, _field), do: query

        defp apply_boolean(query, value, field) when is_boolean(value) do
          where(query, [c], field(c, ^field) == ^value)
        end
      end
    ]
  end

  # "Before days" means the event happened MORE than N days ago.
  # e.g. last_order_before_days: 90 → last order was over 90 days ago.
  # Records with a nil field are included (treated as "never ordered").
  def query_helpers(:days_ago, _name, _opts) do
    [
      quote do
        defp apply_days_ago(query, nil, _field), do: query

        defp apply_days_ago(query, days, field) when is_integer(days) do
          cutoff_date =
            DateTime.utc_now()
            |> DateTime.add(-days * 24 * 60 * 60, :second)
            |> DateTime.truncate(:second)

          where(query, [c], field(c, ^field) < ^cutoff_date or is_nil(field(c, ^field)))
        end
      end
    ]
  end

  # :days_range exposes two independent clauses on the same timestamp column:
  #   before_days - event happened MORE than N days ago  (field < cutoff)
  #   after_days  - event happened LESS than N days ago  (field >= cutoff)
  # Either can be nil, in which case that bound is simply not applied.
  def query_helpers(:days_range, _name, _opts) do
    [
      quote do
        defp apply_days_range(query, before_days, after_days, field) do
          query =
            if before_days do
              cutoff =
                DateTime.utc_now()
                |> DateTime.add(-before_days * 24 * 60 * 60, :second)
                |> DateTime.truncate(:second)

              where(query, [c], field(c, ^field) < ^cutoff or is_nil(field(c, ^field)))
            else
              query
            end

          if after_days do
            cutoff =
              DateTime.utc_now()
              |> DateTime.add(-after_days * 24 * 60 * 60, :second)
              |> DateTime.truncate(:second)

            where(query, [c], field(c, ^field) >= ^cutoff)
          else
            query
          end
        end
      end
    ]
  end

  # ── ui_metadata ───────────────────────────────────────────────────────────
  # Returns a map consumed by the traditional filter UI to know what kind of
  # input to render and how to label it.

  def ui_metadata(:integer_range, name, opts) do
    ui_opts = Map.get(opts, :ui, [])

    %{
      type: :integer_range,
      label: Keyword.get(ui_opts, :label, Phoenix.Naming.humanize(name)),
      format: Keyword.get(ui_opts, :format),
      fields: %{min: :"#{name}_min", max: :"#{name}_max"}
    }
  end

  def ui_metadata(:enum, name, opts) do
    ui_opts = Map.get(opts, :ui, [])
    values = Map.get(opts, :values, [])

    %{
      type: :enum,
      label: Keyword.get(ui_opts, :label, Phoenix.Naming.humanize(name)),
      input_type: Keyword.get(ui_opts, :type, :select),
      options: values,
      field: name
    }
  end

  def ui_metadata(:string_match, name, opts) do
    ui_opts = Map.get(opts, :ui, [])

    %{
      type: :string_match,
      label: Keyword.get(ui_opts, :label, Phoenix.Naming.humanize(name)),
      input_type: :text,
      placeholder: Keyword.get(ui_opts, :placeholder),
      field: name
    }
  end

  def ui_metadata(:boolean, name, opts) do
    ui_opts = Map.get(opts, :ui, [])

    %{
      type: :boolean,
      label: Keyword.get(ui_opts, :label, Phoenix.Naming.humanize(name)),
      input_type: :select,
      field: name
    }
  end

  def ui_metadata(:days_ago, name, opts) do
    ui_opts = Map.get(opts, :ui, [])

    %{
      type: :days_ago,
      label: Keyword.get(ui_opts, :label, Phoenix.Naming.humanize("#{name} before days")),
      input_type: :number,
      field: :"#{name}_before_days"
    }
  end

  def ui_metadata(:days_range, name, opts) do
    ui_opts = Map.get(opts, :ui, [])
    base_label = Keyword.get(ui_opts, :label, Phoenix.Naming.humanize(name))

    %{
      type: :days_range,
      label: base_label,
      fields: %{before: :"#{name}_before_days", after: :"#{name}_after_days"}
    }
  end

  # ── ai_hint ───────────────────────────────────────────────────────────────
  # Returns a plain-English string appended to @llm_doc in AISchema.
  # This is the primary mechanism for telling the LLM how to populate each
  # field from natural language input.

  def ai_hint(:integer_range, name, opts) do
    hint = Map.get(opts, :ai_hint, "Integer range for #{name}")
    "- #{name}_min/#{name}_max: #{hint}"
  end

  def ai_hint(:enum, name, opts) do
    values = Map.get(opts, :values, [])
    hint = Map.get(opts, :ai_hint, "One of: #{Enum.join(values, ", ")}")
    "- #{name}: #{hint}"
  end

  def ai_hint(:string_match, name, opts) do
    hint = Map.get(opts, :ai_hint, "String value for #{name}")
    "- #{name}: #{hint}"
  end

  def ai_hint(:boolean, name, opts) do
    hint = Map.get(opts, :ai_hint, "Boolean value for #{name}")
    "- #{name}: #{hint}"
  end

  def ai_hint(:days_ago, name, opts) do
    hint = Map.get(opts, :ai_hint, "Number of days ago for #{name}")
    "- #{name}_before_days: #{hint}"
  end

  def ai_hint(:days_range, name, opts) do
    hint = Map.get(opts, :ai_hint, "Number of days for #{name} range")

    "- #{name}_before_days: #{hint} (event was more than X days ago)\n- #{name}_after_days: #{hint} (event was less than X days ago, i.e. recently)"
  end
end
