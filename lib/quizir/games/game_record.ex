defmodule Quizir.Games.GameRecord do
  use Ecto.Schema
  import Ecto.Changeset

  schema "game_records" do
    field :code, :string
    field :quiz_title, :string
    field :visibility, :string, default: "public"
    field :players_count, :integer, default: 0
    field :winner_name, :string
    field :winner_score, :integer, default: 0
    field :status, :string, default: "completed"
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime

    belongs_to :quiz, Quizir.Quizzes.Quiz
    belongs_to :host_user, Quizir.Accounts.User, foreign_key: :host_user_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(game_record, attrs) do
    game_record
    |> cast(attrs, [
      :code,
      :quiz_id,
      :quiz_title,
      :host_user_id,
      :visibility,
      :players_count,
      :winner_name,
      :winner_score,
      :status,
      :started_at,
      :finished_at
    ])
    |> validate_required([:code, :quiz_title])
  end
end
