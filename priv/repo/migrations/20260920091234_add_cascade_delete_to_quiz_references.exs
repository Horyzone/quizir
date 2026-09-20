defmodule Quizir.Repo.Migrations.AddCascadeDeleteToQuizReferences do
  use Ecto.Migration

  def change do
    drop constraint(:questions, "questions_quiz_id_fkey")

    alter table(:questions) do
      modify :quiz_id, references(:quizzes, on_delete: :delete_all)
    end

    drop constraint(:answer_options, "answer_options_question_id_fkey")

    alter table(:answer_options) do
      modify :question_id, references(:questions, on_delete: :delete_all)
    end
  end
end
