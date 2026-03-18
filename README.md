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
└── example_liveview_ai_ux/
    └── customers/
        ├── customer.ex          # Ecto schema — the data model
        ├── customer_filter.ex   # Embedded schema defining available filter fields
        ├── customer_filters.ex  # Deterministic query composition (no AI here)
        └── intent_filters.ex    # AI parsing layer — translates text → CustomerFilter
```

**`CustomerFilter`** is a plain embedded Ecto schema. All filter state lives
here, whether it came from the manual form or from the LLM.

**`CustomerFilters`** contains pure query functions. It knows nothing about AI
or user intent — it just takes a `CustomerFilter` and builds a composable Ecto
query. This is the deterministic core.

**`IntentFilters`** is the AI layer. It sends the user's natural language
request to the LLM via InstructorEx, receives a validated struct, and maps it
onto a `CustomerFilter`. If the LLM call fails or returns an invalid response,
it returns an error tuple — the rest of the system is unaffected.

**`CustomerLive.Index`** is the LiveView. It handles both the manual form
(`phx-change="update_filter"`) and the natural language form
(`phx-submit="apply_intent"`), routing both paths through the same query logic.

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
