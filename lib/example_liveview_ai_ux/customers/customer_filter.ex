defmodule ExampleLiveviewAiUx.Customers.CustomerFilter do
  use Ecto.Schema
  import Ecto.Changeset

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

  @fields [
    :min_total_spend,
    :max_total_spend,
    :min_orders_count,
    :max_orders_count,
    :last_order_before_days,
    :last_order_after_days,
    :signed_up_before_days,
    :signed_up_after_days,
    :status,
    :country,
    :segment,
    :has_open_support_ticket
  ]

  def new do
    %__MODULE__{}
  end

  def changeset(filter, attrs) do
    filter
    |> cast(attrs, @fields)
    |> validate_number(:min_total_spend, greater_than_or_equal_to: 0)
    |> validate_number(:max_total_spend, greater_than_or_equal_to: 0)
    |> validate_number(:min_orders_count, greater_than_or_equal_to: 0)
    |> validate_number(:max_orders_count, greater_than_or_equal_to: 0)
    |> validate_number(:last_order_before_days, greater_than: 0)
    |> validate_number(:last_order_after_days, greater_than: 0)
    |> validate_number(:signed_up_before_days, greater_than: 0)
    |> validate_number(:signed_up_after_days, greater_than: 0)
    |> validate_spend_range()
    |> validate_orders_range()
  end

  def metadata do
    %{
      min_total_spend: %{
        label: "Minimum Total Spend",
        type: :number,
        description: "Minimum amount spent (in cents)"
      },
      max_total_spend: %{
        label: "Maximum Total Spend", 
        type: :number,
        description: "Maximum amount spent (in cents)"
      },
      min_orders_count: %{
        label: "Minimum Orders Count",
        type: :number,
        description: "Minimum number of orders placed"
      },
      max_orders_count: %{
        label: "Maximum Orders Count",
        type: :number, 
        description: "Maximum number of orders placed"
      },
      last_order_before_days: %{
        label: "Last Order Before (Days)",
        type: :number,
        description: "Last order was before X days ago"
      },
      last_order_after_days: %{
        label: "Last Order After (Days)",
        type: :number,
        description: "Last order was after X days ago"
      },
      signed_up_before_days: %{
        label: "Signed Up Before (Days)",
        type: :number,
        description: "Signed up before X days ago"
      },
      signed_up_after_days: %{
        label: "Signed Up After (Days)", 
        type: :number,
        description: "Signed up after X days ago"
      },
      status: %{
        label: "Status",
        type: :select,
        options: [:active, :inactive, :churn_risk, :vip],
        description: "Customer status"
      },
      country: %{
        label: "Country",
        type: :text,
        description: "Customer country"
      },
      segment: %{
        label: "Segment",
        type: :select,
        options: [:smb, :enterprise, :consumer],
        description: "Customer segment"
      },
      has_open_support_ticket: %{
        label: "Has Open Support Ticket",
        type: :checkbox,
        description: "Customer has an open support ticket"
      }
    }
  end

  defp validate_spend_range(changeset) do
    min_spend = get_field(changeset, :min_total_spend)
    max_spend = get_field(changeset, :max_total_spend)

    case {min_spend, max_spend} do
      {min, max} when is_integer(min) and is_integer(max) and min > max ->
        add_error(changeset, :max_total_spend, "must be greater than minimum spend")
      _ ->
        changeset
    end
  end

  defp validate_orders_range(changeset) do
    min_orders = get_field(changeset, :min_orders_count)
    max_orders = get_field(changeset, :max_orders_count)

    case {min_orders, max_orders} do
      {min, max} when is_integer(min) and is_integer(max) and min > max ->
        add_error(changeset, :max_orders_count, "must be greater than minimum orders")
      _ ->
        changeset
    end
  end
end