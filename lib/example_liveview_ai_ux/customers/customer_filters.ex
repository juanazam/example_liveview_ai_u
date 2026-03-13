defmodule ExampleLiveviewAiUx.Customers.CustomerFilters do

  import Ecto.Query, warn: false
  alias ExampleLiveviewAiUx.Customers.CustomerFilter

  def apply(query, %CustomerFilter{} = filter) do
    query
    |> maybe_min_total_spend(filter.min_total_spend)
    |> maybe_max_total_spend(filter.max_total_spend)
    |> maybe_min_orders_count(filter.min_orders_count)
    |> maybe_max_orders_count(filter.max_orders_count)
    |> maybe_last_order_before_days(filter.last_order_before_days)
    |> maybe_last_order_after_days(filter.last_order_after_days)
    |> maybe_signed_up_before_days(filter.signed_up_before_days)
    |> maybe_signed_up_after_days(filter.signed_up_after_days)
    |> maybe_status(filter.status)
    |> maybe_country(filter.country)
    |> maybe_segment(filter.segment)
    |> maybe_has_open_support_ticket(filter.has_open_support_ticket)
  end

  def maybe_min_total_spend(query, nil), do: query
  def maybe_min_total_spend(query, min_spend) when is_integer(min_spend) do
    from c in query, where: c.total_spend >= ^min_spend
  end

  def maybe_max_total_spend(query, nil), do: query
  def maybe_max_total_spend(query, max_spend) when is_integer(max_spend) do
    from c in query, where: c.total_spend <= ^max_spend
  end

  def maybe_min_orders_count(query, nil), do: query
  def maybe_min_orders_count(query, min_orders) when is_integer(min_orders) do
    from c in query, where: c.orders_count >= ^min_orders
  end

  def maybe_max_orders_count(query, nil), do: query
  def maybe_max_orders_count(query, max_orders) when is_integer(max_orders) do
    from c in query, where: c.orders_count <= ^max_orders
  end

  def maybe_last_order_before_days(query, nil), do: query
  def maybe_last_order_before_days(query, days) when is_integer(days) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)
    from c in query, where: c.last_order_at < ^cutoff_date or is_nil(c.last_order_at)
  end

  def maybe_last_order_after_days(query, nil), do: query
  def maybe_last_order_after_days(query, days) when is_integer(days) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)
    from c in query, where: c.last_order_at >= ^cutoff_date
  end

  def maybe_signed_up_before_days(query, nil), do: query
  def maybe_signed_up_before_days(query, days) when is_integer(days) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)
    from c in query, where: c.signed_up_at < ^cutoff_date
  end

  def maybe_signed_up_after_days(query, nil), do: query
  def maybe_signed_up_after_days(query, days) when is_integer(days) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)
    from c in query, where: c.signed_up_at >= ^cutoff_date
  end

  def maybe_status(query, nil), do: query
  def maybe_status(query, status) when status in [:active, :inactive, :churn_risk, :vip] do
    from c in query, where: c.status == ^status
  end

  def maybe_country(query, nil), do: query
  def maybe_country(query, country) when is_binary(country) do
    from c in query, where: c.country == ^country
  end

  def maybe_segment(query, nil), do: query
  def maybe_segment(query, segment) when segment in [:smb, :enterprise, :consumer] do
    from c in query, where: c.segment == ^segment
  end

  def maybe_has_open_support_ticket(query, nil), do: query
  def maybe_has_open_support_ticket(query, has_ticket) when is_boolean(has_ticket) do
    from c in query, where: c.has_open_support_ticket == ^has_ticket
  end
end