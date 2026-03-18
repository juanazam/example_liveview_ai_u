defmodule ExampleLiveviewAiUxWeb.CustomerLive.Index do
  use ExampleLiveviewAiUxWeb, :live_view

  alias ExampleLiveviewAiUx.{Customers, Repo}
  alias ExampleLiveviewAiUx.Customers.SimpleDSLFilters

  @impl true
  def mount(_params, _session, socket) do
    filter = SimpleDSLFilters.new()
    changeset = SimpleDSLFilters.changeset(filter, %{})
    customers = SimpleDSLFilters.apply(Customers.Customer, filter) |> Repo.all()
    count = SimpleDSLFilters.apply(Customers.Customer, filter) |> Repo.aggregate(:count, :id)

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

    case SimpleDSLFilters.parse_intent(intent_text) do
      {:ok, filter} ->
        customers = SimpleDSLFilters.apply(Customers.Customer, filter) |> Repo.all()
        count = SimpleDSLFilters.apply(Customers.Customer, filter) |> Repo.aggregate(:count, :id)

        changeset = SimpleDSLFilters.changeset(filter, %{})

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
  def handle_event("update_filter", %{"filter" => filter_params}, socket) do
    # The spend inputs display dollars but the filter stores cents, so convert back.
    filter_params = dollars_to_cents(filter_params, "total_spend_min")
    filter_params = dollars_to_cents(filter_params, "total_spend_max")

    case SimpleDSLFilters.changeset(socket.assigns.filter, filter_params) do
      %{valid?: true} = changeset ->
        filter = Ecto.Changeset.apply_changes(changeset)
        customers = SimpleDSLFilters.apply(Customers.Customer, filter) |> Repo.all()
        count = SimpleDSLFilters.apply(Customers.Customer, filter) |> Repo.aggregate(:count, :id)

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
    filter = SimpleDSLFilters.new()
    changeset = SimpleDSLFilters.changeset(filter, %{})
    customers = SimpleDSLFilters.apply(Customers.Customer, filter) |> Repo.all()
    count = SimpleDSLFilters.apply(Customers.Customer, filter) |> Repo.aggregate(:count, :id)

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

  # Multiply a form string value by 100 (dollars → cents).
  # Leaves the param unchanged if the value is blank or not a valid number.
  defp dollars_to_cents(params, key) do
    case Map.get(params, key) do
      value when value in [nil, ""] ->
        params

      value ->
        case Integer.parse(value) do
          {dollars, _} -> Map.put(params, key, to_string(dollars * 100))
          :error -> params
        end
    end
  end
end
