defmodule ExampleLiveviewAiUx.Customers.IntentFilters do
  alias ExampleLiveviewAiUx.Customers.CustomerFilter

  # CustomerFilter itself is the Instructor response model — no separate schema
  # needed. Instructor validates the field types; the changeset then applies
  # the business-rule validations (range checks, etc.).
  def parse_filter_from_text(text) when is_binary(text) and text != "" do
    case Instructor.chat_completion(
           model: "gpt-4o-mini",
           max_retries: 3,
           response_model: CustomerFilter,
           messages: [
             %{
               role: "system",
               content: """
               You extract customer filter parameters from natural language queries. Follow these rules exactly:

               CRITICAL RULES:
               1. Only set fields that are EXPLICITLY mentioned in the request. Leave everything else null.
               2. Do NOT assume or infer values that are not stated. For example, do not set country unless the user mentions a country.
               3. Do NOT set has_open_support_ticket unless the user explicitly mentions support tickets.

               SPEND DIRECTION (very important — get this right):
               - "spent MORE than X" / "spent at least X" / "high spenders" → min_total_spend (NOT max_total_spend)
               - "spent LESS than X" / "spent at most X" / "low spenders" → max_total_spend (NOT min_total_spend)
               - Always convert dollar amounts to cents by multiplying by 100.
               """
             },
             %{role: "user", content: text}
           ]
         ) do
      {:ok, filter} ->
        # Strip nil values so only fields the LLM actually populated are cast.
        # This also prevents string "null" values from leaking through as
        # literal filter values.
        sanitized =
          filter |> Map.from_struct() |> Map.reject(fn {_, v} -> is_nil(v) or v == "null" end)

        case CustomerFilter.changeset(%CustomerFilter{}, sanitized) do
          %{valid?: true} = changeset -> {:ok, Ecto.Changeset.apply_changes(changeset)}
          changeset -> {:error, "Invalid filter parameters: #{inspect(changeset.errors)}"}
        end

      {:error, reason} ->
        {:error, "Failed to process filter intent: #{inspect(reason)}"}
    end
  end

  def parse_filter_from_text(""), do: {:error, "Empty request"}
  def parse_filter_from_text(nil), do: {:error, "Empty request"}
end
