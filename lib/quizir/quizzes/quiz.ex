defmodule Quizir.Quizzes.Quiz do
  use Ecto.Schema
  import Ecto.Changeset

  schema "quizzes" do
    field :title, :string
    field :description, :string
    field :visibility, :string, default: "public"

    belongs_to :user, Quizir.Accounts.User
    has_many :questions, Quizir.Quizzes.Question, on_delete: :delete_all, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(quiz, attrs) do
    quiz
    |> cast(attrs, [:title, :description, :visibility])
    |> validate_required([:title, :visibility])
    |> validate_inclusion(:visibility, ["public", "private"])
    # Permet de recevoir et valider les questions liées
    |> cast_assoc(:questions, with: &Quizir.Quizzes.Question.changeset/2)
  end
end
