defmodule Quizir.Repo.Migrations.AddUserIdToQuizzes do
  use Ecto.Migration

  def change do
    alter table(:quizzes) do
      add :user_id, references(:users, on_delete: :nilify_all)
    end

    create index(:quizzes, [:user_id])
  end
end
