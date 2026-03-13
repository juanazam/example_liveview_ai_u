defmodule ExampleLiveviewAiUx.Customers.IntentFilters do
  alias ExampleLiveviewAiUx.Customers.CustomerFilter

  defmodule AIFilterResponse do
    use Ecto.Schema
    use Instructor

    @llm_doc """
    Customer filter parameters extracted from natural language requests.
    
    Available filter fields:
    - min_total_spend: minimum amount spent in cents (e.g., 50000 for $500)
    - max_total_spend: maximum amount spent in cents
    - min_orders_count: minimum number of orders
    - max_orders_count: maximum number of orders  
    - last_order_before_days: last order was before X days ago
    - last_order_after_days: last order was after X days ago (more recent than X days)
    - signed_up_before_days: signed up before X days ago
    - signed_up_after_days: signed up after X days ago (more recent than X days)
    - status: one of "active", "inactive", "churn_risk", "vip"
    - country: country name as string
    - segment: one of "smb", "enterprise", "consumer"  
    - has_open_support_ticket: true or false

    Use null/nil for fields not mentioned in the request.
    Convert dollar amounts to cents (multiply by 100).
    For time references: "recently" = ~30 days, "long time" = ~90 days, "months" = multiply by 30.
    """

    @primary_key false
    embedded_schema do
      field :min_total_spend, :integer
      field :max_total_spend, :integer
      field :min_orders_count, :integer
      field :max_orders_count, :integer
      field :last_order_before_days, :integer
      field :last_order_after_days, :integer
      field :signed_up_before_days, :integer
      field :signed_up_after_days, :integer
      field :status, Ecto.Enum, values: [:active, :inactive, :churn_risk, :vip]
      field :country, :string
      field :segment, Ecto.Enum, values: [:smb, :enterprise, :consumer]
      field :has_open_support_ticket, :boolean
    end
  end

  def parse_filter_from_text(text) when is_binary(text) and text != "" do
    user_prompt = "Convert this customer request to filter parameters: #{text}"

    case Instructor.chat_completion(
           model: "gpt-3.5-turbo",
           max_retries: 2,
           response_model: AIFilterResponse,
           messages: [
             %{role: "user", content: user_prompt}
           ]
         ) do
      {:ok, ai_response} ->
        filter = %CustomerFilter{
          min_total_spend: ai_response.min_total_spend,
          max_total_spend: ai_response.max_total_spend,
          min_orders_count: ai_response.min_orders_count,
          max_orders_count: ai_response.max_orders_count,
          last_order_before_days: ai_response.last_order_before_days,
          last_order_after_days: ai_response.last_order_after_days,
          signed_up_before_days: ai_response.signed_up_before_days,
          signed_up_after_days: ai_response.signed_up_after_days,
          status: ai_response.status,
          country: ai_response.country,
          segment: ai_response.segment,
          has_open_support_ticket: ai_response.has_open_support_ticket
        }

        case CustomerFilter.changeset(filter, %{}) do
          %{valid?: true} = changeset ->
            {:ok, Ecto.Changeset.apply_changes(changeset)}
          changeset ->
            {:error, "Invalid filter parameters: #{inspect(changeset.errors)}"}
        end

      {:error, reason} ->
        {:error, "Failed to parse request: #{inspect(reason)}"}
    end
  end

  def parse_filter_from_text(""), do: {:error, "Empty request"}
  def parse_filter_from_text(nil), do: {:error, "Empty request"}
end