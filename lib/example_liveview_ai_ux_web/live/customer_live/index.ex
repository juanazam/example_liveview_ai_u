defmodule ExampleLiveviewAiUxWeb.CustomerLive.Index do
  use ExampleLiveviewAiUxWeb, :live_view

  alias ExampleLiveviewAiUx.Customers
  alias ExampleLiveviewAiUx.Customers.{IntentFilters}

  @impl true
  def mount(_params, _session, socket) do
    filter = Customers.new_customer_filter()
    changeset = Customers.change_customer_filter(filter)
    customers = Customers.list_customers(filter)
    count = Customers.count_customers(filter)

    socket =
      socket
      |> assign(:filter, filter)
      |> assign(:changeset, changeset)
      |> assign(:customers, customers)
      |> assign(:count, count)
      |> assign(:intent_input, "")
      |> assign(:intent_error, nil)
      |> assign(:parse_status, nil)
      |> assign(:debug_info, %{})
      |> assign(:loading, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("apply_intent", %{"intent" => intent_text}, socket) do
    socket = assign(socket, :loading, true)

    case IntentFilters.parse_filter_from_text(intent_text) do
      {:ok, filter} ->
        customers = Customers.list_customers(filter)
        count = Customers.count_customers(filter)

        changeset = Customers.change_customer_filter(filter)

        socket =
          socket
          |> assign(:filter, filter)
          |> assign(:changeset, changeset)
          |> assign(:customers, customers)
          |> assign(:count, count)
          |> assign(:intent_input, intent_text)
          |> assign(:intent_error, nil)
          |> assign(:parse_status, :success)
          |> assign(:debug_info, %{
            input: intent_text,
            parsed_filter: filter,
            status: "success"
          })
          |> assign(:loading, false)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:intent_input, intent_text)
          |> assign(:intent_error, reason)
          |> assign(:parse_status, :error)
          |> assign(:debug_info, %{
            input: intent_text,
            error: reason,
            status: "error"
          })
          |> assign(:loading, false)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_filter", %{"customer_filter" => filter_params}, socket) do
    case Customers.change_customer_filter(socket.assigns.filter, filter_params) do
      %{valid?: true} = changeset ->
        filter = Ecto.Changeset.apply_changes(changeset)
        customers = Customers.list_customers(filter)
        count = Customers.count_customers(filter)

        socket =
          socket
          |> assign(:filter, filter)
          |> assign(:changeset, changeset)
          |> assign(:customers, customers)
          |> assign(:count, count)

        {:noreply, socket}

      _changeset ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    filter = Customers.new_customer_filter()
    changeset = Customers.change_customer_filter(filter)
    customers = Customers.list_customers(filter)
    count = Customers.count_customers(filter)

    socket =
      socket
      |> assign(:filter, filter)
      |> assign(:changeset, changeset)
      |> assign(:customers, customers)
      |> assign(:count, count)
      |> assign(:intent_input, "")
      |> assign(:intent_error, nil)
      |> assign(:parse_status, nil)
      |> assign(:debug_info, %{})

    {:noreply, socket}
  end
end