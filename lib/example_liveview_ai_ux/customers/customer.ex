defmodule ExampleLiveviewAiUx.Customers.Customer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "customers" do
    field :name, :string
    field :email, :string
    field :status, Ecto.Enum, values: [:active, :inactive, :churn_risk, :vip]
    field :total_spend, :integer
    field :orders_count, :integer
    field :last_order_at, :utc_datetime
    field :signed_up_at, :utc_datetime
    field :country, :string
    field :segment, Ecto.Enum, values: [:smb, :enterprise, :consumer]
    field :has_open_support_ticket, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(customer, attrs) do
    customer
    |> cast(attrs, [
      :name,
      :email,
      :status,
      :total_spend,
      :orders_count,
      :last_order_at,
      :signed_up_at,
      :country,
      :segment,
      :has_open_support_ticket
    ])
    |> validate_required([
      :name,
      :email,
      :status,
      :total_spend,
      :orders_count,
      :signed_up_at,
      :country,
      :segment
    ])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
    |> validate_number(:total_spend, greater_than_or_equal_to: 0)
    |> validate_number(:orders_count, greater_than_or_equal_to: 0)
    |> unique_constraint(:email)
  end
end
