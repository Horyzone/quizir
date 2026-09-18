defmodule Quizir.Quizzes.AnswerOption do
  use Ecto.Schema
  import Ecto.Changeset

  schema "answer_options" do
    field :body, :string
    field :is_correct, :boolean, default: false

    belongs_to :question, Quizir.Quizzes.Question

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(answer_option, attrs) do
    answer_option
    |> cast(attrs, [:body, :is_correct, :question_id])
    |> validate_required([:body, :is_correct])
  end
end
