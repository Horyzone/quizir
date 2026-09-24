defmodule Quizir.Repo.Migrations.AddImageUrlToQuizzesAndQuestions do
  use Ecto.Migration

  def change do
    alter table(:quizzes) do
      add :image_url, :text
    end

    alter table(:questions) do
      add :image_url, :text
    end
  end
end
