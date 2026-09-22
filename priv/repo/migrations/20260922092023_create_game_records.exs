defmodule Quizir.Repo.Migrations.CreateGameRecords do
  use Ecto.Migration

  def change do
    create table(:game_records) do
      add :code, :string, null: false
      add :quiz_id, references(:quizzes, on_delete: :nilify_all)
      add :quiz_title, :string, null: false
      add :host_user_id, references(:users, on_delete: :nilify_all)
      add :visibility, :string, default: "public", null: false
      add :players_count, :integer, default: 0, null: false
      add :winner_name, :string
      add :winner_score, :integer, default: 0
      add :status, :string, default: "completed", null: false
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:game_records, [:quiz_id])
    create index(:game_records, [:host_user_id])
    create index(:game_records, [:status])
    create index(:game_records, [:inserted_at])
  end
end
