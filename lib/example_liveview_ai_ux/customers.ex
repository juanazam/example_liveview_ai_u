defmodule ExampleLiveviewAiUx.Customers do

  import Ecto.Query, warn: false
  alias ExampleLiveviewAiUx.Repo
  alias ExampleLiveviewAiUx.Customers.{Customer, CustomerFilter, CustomerFilters}

  def list_customers do
    Repo.all(Customer)
  end

  def list_customers(%CustomerFilter{} = filter) do
    Customer
    |> CustomerFilters.apply(filter)
    |> order_by([c], desc: c.signed_up_at)
    |> Repo.all()
  end

  def count_customers(%CustomerFilter{} = filter) do
    Customer
    |> CustomerFilters.apply(filter)
    |> Repo.aggregate(:count, :id)
  end

  def get_customer!(id), do: Repo.get!(Customer, id)

  def create_customer(attrs \\ %{}) do
    %Customer{}
    |> Customer.changeset(attrs)
    |> Repo.insert()
  end

  def update_customer(%Customer{} = customer, attrs) do
    customer
    |> Customer.changeset(attrs)
    |> Repo.update()
  end

  def delete_customer(%Customer{} = customer) do
    Repo.delete(customer)
  end

  def change_customer(%Customer{} = customer, attrs \\ %{}) do
    Customer.changeset(customer, attrs)
  end

  def change_customer_filter(%CustomerFilter{} = filter, attrs \\ %{}) do
    CustomerFilter.changeset(filter, attrs)
  end

  def new_customer_filter do
    CustomerFilter.new()
  end
end