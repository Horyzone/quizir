defmodule Quizir.Quizzes.Question do
  use Ecto.Schema
  import Ecto.Changeset

  schema "questions" do
    field :body, :string
    field :order, :integer, default: 1
    field :time_limit_seconds, :integer, default: 20
    field :image_url, :string
    field :temp_id, :string, virtual: true

    belongs_to :quiz, Quizir.Quizzes.Quiz

    has_many :answer_options, Quizir.Quizzes.AnswerOption,
      on_delete: :delete_all,
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(question, attrs) do
    question
    |> cast(attrs, [:body, :order, :time_limit_seconds, :quiz_id, :image_url, :temp_id])
    |> validate_required([:body, :order, :time_limit_seconds])
    |> validate_number(:time_limit_seconds, greater_than: 4, less_than: 121)
    # Permet de recevoir et valider les choix de réponse
    |> cast_assoc(:answer_options, with: &Quizir.Quizzes.AnswerOption.changeset/2)
  end
end
