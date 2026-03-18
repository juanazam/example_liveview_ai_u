# AI Filtering Demo App

> **This is an example project** built to accompany a blog post about using AI
> as an intent layer on top of a deterministic filtering system. It is not
> production-ready code. The goal is to illustrate a practical pattern in the
> simplest possible way.

## The idea

As products grow, filter UIs tend to become unwieldy — many dropdowns, nested
conditions, AND/OR logic. Users already know what they want; the friction is
translating that intent into whatever structure the UI requires.

This app shows a practical answer to that problem:

```
User input (natural language)
  → Intent layer (LLM via InstructorEx)
  → Structured filter parameters
  → Deterministic query logic   ← unchanged, always in control
  → Database results
```

The LLM only produces structured filter parameters. It never writes SQL or
touches the query layer. Everything after the structured filter is
deterministic and testable.

## Key features

- **Natural language filtering** — describe the customers you want in plain English
- **Traditional filter UI** — manual controls stay available and editable alongside the AI input
- **Shared filter state** — AI-generated filters populate the same `CustomerFilter` struct as the manual form, so the same query logic runs regardless of how a filter was produced
- **Inspect and edit** — users can review and adjust any AI-generated filter before relying on it
- **Debug panel** — shows the last natural language input and the parsed filter struct
- **InstructorEx** — handles structured output, schema validation, and retries so the application code stays simple

## Why InstructorEx

Without structured output tooling, you end up writing your own response
parsing, schema validation, repair prompts, retry loops, and error handling.
InstructorEx handles all of that. The application code defines a response
model and calls `Instructor.chat_completion/1` — it either receives a
validated struct or an error.

One important caveat the demo preserves: a schema-valid response is not always
the *correct* interpretation of the user's request. That is why the UI lets
users inspect and edit generated filters rather than applying them blindly.

## Architecture

```
lib/
├── ecto_filters/
│   ├── ecto_filters.ex      # use EctoFilters macro + compile-time code generation
│   ├── dsl.ex               # filter :name do ... end macro
│   └── types.ex             # per-type schema fields, validations, query helpers, metadata
│
└── example_liveview_ai_ux/
    └── customers/
        ├── customer.ex                # Ecto schema — the data model
        └── simple_dsl_filters.ex      # filter module defined with the EctoFilters DSL
```

**`CustomerLive.Index`** is the LiveView. It handles both the manual form
(`phx-change="update_filter"`) and the natural language form
(`phx-submit="apply_intent"`), routing both paths through the same query logic.

## The EctoFilters DSL

This branch explores a next step: a small DSL that lets you declare a filter
module once and get the following generated for free at compile time:

- An embedded Ecto schema (`Filter`) for holding filter state
- A `changeset/2` function for casting and validating form params
- A composable `apply/2` function for building Ecto queries
- An `AISchema` submodule (backed by InstructorEx) for LLM parsing
- A `parse_intent/1` function that turns natural language into a `Filter`
- A `ui_metadata/0` map with hints for rendering traditional filter inputs

The same filter definition drives the query layer, the traditional UI, and the
AI intent layer. Define it once; all three stay in sync automatically.

### Defining a filter module

```elixir
defmodule MyApp.CustomerFilters do
  use EctoFilters, schema: MyApp.Customer

  filter :total_spend do
    type :integer_range          # generates total_spend_min / total_spend_max
    field :total_spend           # column on the Ecto schema
    ui label: "Total Spend", format: :currency
    ai_hint "Convert dollar amounts to cents (multiply by 100)"
  end

  filter :status do
    type :enum
    field :status
    values [:active, :inactive, :churn_risk, :vip]
    ui label: "Status", type: :select
    ai_hint "One of: active, inactive, churn_risk, vip"
  end

  filter :country do
    type :string_match
    field :country
    ui label: "Country", placeholder: "e.g. USA, Canada"
    ai_hint "Country name as a string"
  end

  filter :last_order do
    type :days_range             # generates last_order_before_days / last_order_after_days
    field :last_order_at
    ui label: "Last Order"
    ai_hint "Use before_days for 'no order in X days', after_days for 'ordered within X days'"
  end

  filter :has_open_support_ticket do
    type :boolean
    field :has_open_support_ticket
    ui label: "Open Support Ticket"
    ai_hint "true if the customer has an open support ticket"
  end
end
```

### Supported filter types

| Type | Generated fields | Use for |
|---|---|---|
| `:integer_range` | `name_min`, `name_max` | Numeric ranges (spend, order count) |
| `:enum` | `name` | Fixed set of atom values |
| `:string_match` | `name` | Exact string equality |
| `:boolean` | `name` | True/false flags |
| `:days_ago` | `name_before_days` | "event happened more than N days ago" |
| `:days_range` | `name_before_days`, `name_after_days` | Both before and after bounds on a timestamp |

### Using the generated module

```elixir
# Build an empty filter (all fields nil = no filtering)
filter = MyApp.CustomerFilters.new()

# Cast params from a form (phx-change)
changeset = MyApp.CustomerFilters.changeset(filter, %{
  "status" => "active",
  "total_spend_min" => "50000"
})

# Apply to an Ecto query
customers =
  MyApp.Customer
  |> MyApp.CustomerFilters.apply(filter)
  |> Repo.all()

# Parse natural language into a filter
{:ok, filter} = MyApp.CustomerFilters.parse_intent("inactive customers who spent over $500")

# UI rendering hints
MyApp.CustomerFilters.ui_metadata()
# => %{status: %{type: :enum, label: "Status", options: [...], ...}, ...}
```

### Compile-time validation

The DSL validates filter declarations against the target Ecto schema at compile
time, so mistakes are caught immediately rather than at runtime:

```
** (ArgumentError) EctoFilters: filter :last_order targets field :last_order_date,
   but MyApp.Customer has no such field.
   Did you mean :last_order_at?
   Available fields: [:id, :name, :status, :last_order_at, ...]
```

Type mismatches are also caught:

```
** (ArgumentError) EctoFilters: filter :country has type :days_range,
   which expects [:utc_datetime, :naive_datetime, ...],
   but field :country on the schema is :string.
```

## Setup

1. **Set your OpenAI API key**:
   ```bash
   export OPENAI_API_KEY="your-api-key-here"
   ```

2. **Install dependencies and set up the database**:
   ```bash
   mix setup
   ```

3. **Start the server**:
   ```bash
   mix phx.server
   ```

4. **Open the app**:
   [`localhost:4000`](http://localhost:4000)

## Example prompts to try

- `customers who spent more than $500 and are inactive`
- `enterprise customers with open tickets`
- `people who signed up recently but have not ordered yet`
- `customers from Uruguay who have not purchased in 6 months`
- `customers that spend a lot but haven't bought anything in a while`

The last example is intentional — it produces a schema-valid filter that may
still be semantically wrong for your context, illustrating that AI output
should be treated as a starting point, not a final answer.
