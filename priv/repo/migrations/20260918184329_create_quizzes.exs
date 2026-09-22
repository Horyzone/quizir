defmodule Quizir.Repo.Migrations.CreateQuizzes do
  use Ecto.Migration

  def change do
    create table(:quizzes) do
      add :title, :string
      add :description, :text
      add :visibility, :string
      add :access_code, :string

      timestamps(type: :utc_datetime)
    end
  end
end
