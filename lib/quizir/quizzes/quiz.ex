defmodule Quizir.Quizzes.Quiz do
  use Ecto.Schema
  import Ecto.Changeset

  schema "quizzes" do
    field :title, :string
    field :description, :string
    field :visibility, :string, default: "public"
    field :access_code, :string

    has_many :questions, Quizir.Quizzes.Question, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(quiz, attrs) do
    quiz
    |> cast(attrs, [:title, :description, :visibility, :access_code])
    |> validate_required([:title, :visibility])
    |> validate_inclusion(:visibility, ["public", "private"])
    |> validate_access_code_if_private()
  end

  defp validate_access_code_if_private(changeset) do
    if get_field(changeset, :visibility) == "private" do
      validate_required(changeset, [:access_code])
    else
      changeset
    end
  end
end
