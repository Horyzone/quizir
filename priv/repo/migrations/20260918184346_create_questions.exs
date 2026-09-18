defmodule Quizir.Repo.Migrations.CreateQuestions do
  use Ecto.Migration

  def change do
    create table(:questions) do
      add :body, :text
      add :order, :integer
      add :time_limit_seconds, :integer
      add :quiz_id, references(:quizzes, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:questions, [:quiz_id])
  end
end
