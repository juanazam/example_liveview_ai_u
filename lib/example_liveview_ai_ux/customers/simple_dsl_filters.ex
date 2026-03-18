defmodule ExampleLiveviewAiUx.Customers.SimpleDSLFilters do
  use EctoFilters, schema: ExampleLiveviewAiUx.Customers.Customer

  filter :total_spend do
    type(:integer_range)
    field :total_spend
    ui(label: "Total Spend", format: :currency)
    ai_hint("Convert dollar amounts to cents (multiply by 100). e.g., $500 becomes 50000")
  end

  filter :orders_count do
    type(:integer_range)
    field :orders_count
    ui(label: "Orders Count")
    ai_hint("Number of orders placed. Use 0 for customers who have never ordered.")
  end

  filter :last_order do
    type(:days_range)
    field :last_order_at
    ui(label: "Last Order")

    ai_hint(
      "Days since last order. Use before_days for 'hasn't ordered in X days' (e.g. 90 for 3 months). Use after_days for 'ordered within last X days' (e.g. 30 for recently)."
    )
  end

  filter :signed_up do
    type(:days_range)
    field :signed_up_at
    ui(label: "Signed Up")

    ai_hint(
      "Days since signup. Use before_days for 'signed up more than X days ago'. Use after_days for 'signed up within last X days' (recently)."
    )
  end

  filter :status do
    type(:enum)
    field :status
    values([:active, :inactive, :churn_risk, :vip])
    ui(label: "Customer Status", type: :select)
    ai_hint("One of: active, inactive, churn_risk, vip")
  end

  filter :segment do
    type(:enum)
    field :segment
    values([:smb, :enterprise, :consumer])
    ui(label: "Segment", type: :select)
    ai_hint("One of: smb, enterprise, consumer")
  end

  filter :country do
    type(:string_match)
    field :country
    ui(label: "Country", placeholder: "e.g., USA, Canada, Uruguay")
    ai_hint("Country name as string")
  end

  filter :has_open_support_ticket do
    type(:boolean)
    field :has_open_support_ticket
    ui(label: "Has Open Support Ticket")
    ai_hint("true if the customer has an open support ticket, false otherwise")
  end
end
