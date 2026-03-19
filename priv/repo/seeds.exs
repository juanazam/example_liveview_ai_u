alias ExampleLiveviewAiUx.Repo
alias ExampleLiveviewAiUx.Customers.Customer

Repo.delete_all(Customer)

countries = [
  "USA",
  "Canada",
  "Brazil",
  "Uruguay",
  "UK",
  "Germany",
  "France",
  "Australia",
  "Japan",
  "Singapore"
]

statuses = [:active, :inactive, :churn_risk, :vip]
segments = [:smb, :enterprise, :consumer]

names = [
  "Alice Johnson",
  "Bob Smith",
  "Carol Davis",
  "David Wilson",
  "Eva Brown",
  "Frank Miller",
  "Grace Lee",
  "Henry Taylor",
  "Iris Chen",
  "Jack Williams",
  "Kate Anderson",
  "Liam Garcia",
  "Maya Patel",
  "Noah Kim",
  "Olivia Martinez",
  "Paul Rodriguez",
  "Quinn Thompson",
  "Rita Singh",
  "Sam Jackson",
  "Tina Liu",
  "Uma Johnson",
  "Victor Chang",
  "Wendy Zhang",
  "Xander Silva",
  "Yuki Tanaka",
  "Zoe Foster",
  "Aaron Brooks",
  "Bella Cooper",
  "Charlie Reed",
  "Diana Bell",
  "Ethan Gray",
  "Fiona Murphy",
  "Gabriel Ward",
  "Hanna Price",
  "Ivan Ross",
  "Julia Perry",
  "Kevin Powell",
  "Luna Cox",
  "Mason Hughes",
  "Nina Wells"
]

base_time = DateTime.utc_now() |> DateTime.truncate(:second)

edge_cases = [
  %{
    name: "Maxwell Enterprise Corp",
    email: "contact@maxwell.corp",
    status: :inactive,
    total_spend: 50000,
    orders_count: 25,
    last_order_at:
      DateTime.add(base_time, -120 * 24 * 60 * 60, :second) |> DateTime.truncate(:second),
    signed_up_at:
      DateTime.add(base_time, -400 * 24 * 60 * 60, :second) |> DateTime.truncate(:second),
    country: "USA",
    segment: :enterprise,
    has_open_support_ticket: true
  },
  %{
    name: "Sarah Dormant",
    email: "sarah.dormant@example.com",
    status: :inactive,
    total_spend: 50,
    orders_count: 1,
    last_order_at:
      DateTime.add(base_time, -300 * 24 * 60 * 60, :second) |> DateTime.truncate(:second),
    signed_up_at:
      DateTime.add(base_time, -350 * 24 * 60 * 60, :second) |> DateTime.truncate(:second),
    country: "Canada",
    segment: :consumer,
    has_open_support_ticket: false
  },
  %{
    name: "Alex NoOrders",
    email: "alex.noorders@example.com",
    status: :active,
    total_spend: 0,
    orders_count: 0,
    last_order_at: nil,
    signed_up_at:
      DateTime.add(base_time, -5 * 24 * 60 * 60, :second) |> DateTime.truncate(:second),
    country: "Brazil",
    segment: :consumer,
    has_open_support_ticket: false
  },
  %{
    name: "BigCorp Industries",
    email: "procurement@bigcorp.com",
    status: :vip,
    total_spend: 150_000,
    orders_count: 45,
    last_order_at:
      DateTime.add(base_time, -7 * 24 * 60 * 60, :second) |> DateTime.truncate(:second),
    signed_up_at:
      DateTime.add(base_time, -500 * 24 * 60 * 60, :second) |> DateTime.truncate(:second),
    country: "Germany",
    segment: :enterprise,
    has_open_support_ticket: false
  },
  %{
    name: "TechStart Solutions",
    email: "admin@techstart.io",
    status: :active,
    total_spend: 75000,
    orders_count: 30,
    last_order_at:
      DateTime.add(base_time, -2 * 24 * 60 * 60, :second) |> DateTime.truncate(:second),
    signed_up_at:
      DateTime.add(base_time, -200 * 24 * 60 * 60, :second) |> DateTime.truncate(:second),
    country: "Singapore",
    segment: :enterprise,
    has_open_support_ticket: true
  },
  %{
    name: "Maria Troubled",
    email: "maria.troubled@example.com",
    status: :churn_risk,
    total_spend: 2500,
    orders_count: 8,
    last_order_at:
      DateTime.add(base_time, -45 * 24 * 60 * 60, :second) |> DateTime.truncate(:second),
    signed_up_at:
      DateTime.add(base_time, -180 * 24 * 60 * 60, :second) |> DateTime.truncate(:second),
    country: "Uruguay",
    segment: :smb,
    has_open_support_ticket: true
  }
]

Enum.each(edge_cases, fn attrs ->
  Repo.insert!(%Customer{
    name: attrs.name,
    email: attrs.email,
    status: attrs.status,
    total_spend: attrs.total_spend,
    orders_count: attrs.orders_count,
    last_order_at: attrs.last_order_at,
    signed_up_at: attrs.signed_up_at,
    country: attrs.country,
    segment: attrs.segment,
    has_open_support_ticket: attrs.has_open_support_ticket
  })
end)

for i <- 1..120 do
  name = Enum.random(names)

  country = Enum.random(countries)
  status = Enum.random(statuses)
  segment = Enum.random(segments)

  orders_count =
    case segment do
      :enterprise -> :rand.uniform(50) + 10
      :smb -> :rand.uniform(20) + 2
      :consumer -> :rand.uniform(10)
    end

  total_spend =
    case {segment, status} do
      {:enterprise, :vip} -> :rand.uniform(100_000) + 50000
      {:enterprise, _} -> :rand.uniform(50000) + 5000
      {:smb, :vip} -> :rand.uniform(20000) + 2000
      {:smb, _} -> :rand.uniform(10000) + 200
      {:consumer, :vip} -> :rand.uniform(5000) + 500
      {:consumer, _} -> :rand.uniform(2000) + 10
    end

  signed_up_days_ago = :rand.uniform(730) + 1

  signed_up_at =
    DateTime.add(base_time, -signed_up_days_ago * 24 * 60 * 60, :second)
    |> DateTime.truncate(:second)

  last_order_at =
    case {status, orders_count} do
      {_, 0} ->
        nil

      {:active, _} ->
        days_ago = :rand.uniform(30)
        DateTime.add(base_time, -days_ago * 24 * 60 * 60, :second) |> DateTime.truncate(:second)

      {:inactive, _} ->
        days_ago = :rand.uniform(150) + 60
        DateTime.add(base_time, -days_ago * 24 * 60 * 60, :second) |> DateTime.truncate(:second)

      {:churn_risk, _} ->
        days_ago = :rand.uniform(60) + 30
        DateTime.add(base_time, -days_ago * 24 * 60 * 60, :second) |> DateTime.truncate(:second)

      {:vip, _} ->
        days_ago = :rand.uniform(14) + 1
        DateTime.add(base_time, -days_ago * 24 * 60 * 60, :second) |> DateTime.truncate(:second)
    end

  has_ticket =
    case status do
      :churn_risk -> :rand.uniform(100) < 60
      :vip -> :rand.uniform(100) < 15
      _ -> :rand.uniform(100) < 10
    end

  email = String.downcase("#{String.replace(name, " ", ".")}#{i}@example.com")

  Repo.insert!(%Customer{
    name: name,
    email: email,
    status: status,
    total_spend: total_spend,
    orders_count: orders_count,
    last_order_at: last_order_at,
    signed_up_at: signed_up_at,
    country: country,
    segment: segment,
    has_open_support_ticket: has_ticket
  })
end
