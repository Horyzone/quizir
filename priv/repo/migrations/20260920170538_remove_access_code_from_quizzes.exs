defmodule Quizir.Repo.Migrations.RemoveAccessCodeFromQuizzes do
  use Ecto.Migration

  def change do
    alter table(:quizzes) do
      remove :access_code, :string
    end
  end
end
