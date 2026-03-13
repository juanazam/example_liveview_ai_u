defmodule ExampleLiveviewAiUx.Repo.Migrations.CreateCustomers do
  use Ecto.Migration

  def change do
    create table(:customers) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :status, :string, null: false
      add :total_spend, :integer, null: false, default: 0
      add :orders_count, :integer, null: false, default: 0
      add :last_order_at, :utc_datetime
      add :signed_up_at, :utc_datetime, null: false
      add :country, :string, null: false
      add :segment, :string, null: false
      add :has_open_support_ticket, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:customers, [:email])
    create index(:customers, [:status])
    create index(:customers, [:total_spend])
    create index(:customers, [:last_order_at])
    create index(:customers, [:signed_up_at])
    create index(:customers, [:country])
    create index(:customers, [:segment])
  end
end
