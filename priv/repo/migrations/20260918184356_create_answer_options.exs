defmodule Quizir.Repo.Migrations.CreateAnswerOptions do
  use Ecto.Migration

  def change do
    create table(:answer_options) do
      add :body, :string
      add :is_correct, :boolean, default: false, null: false
      add :question_id, references(:questions, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:answer_options, [:question_id])
  end
end
