defmodule Quizir.QuizzesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Quizir.Quizzes` context.
  """

  @doc """
  Generate a quiz.
  """
  def quiz_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    user = Map.get(attrs, :user)
    user_id = Map.get(attrs, :user_id)
    user_struct = user || if user_id, do: %Quizir.Accounts.User{id: user_id}, else: nil

    clean_attrs =
      attrs
      |> Map.drop([:user, :user_id])
      |> Enum.into(%{
        access_code: "some access_code",
        description: "some description",
        title: "some title",
        visibility: "public"
      })

    {:ok, quiz} = Quizir.Quizzes.create_quiz(clean_attrs, user_struct)
    Quizir.Repo.preload(quiz, :user)
  end

  @doc """
  Generate a question.
  """
  def question_fixture(attrs \\ %{}) do
    {:ok, question} =
      attrs
      |> Enum.into(%{
        body: "some body",
        order: 42,
        time_limit_seconds: 42
      })
      |> Quizir.Quizzes.create_question()

    question
  end

  @doc """
  Generate a answer_option.
  """
  def answer_option_fixture(attrs \\ %{}) do
    {:ok, answer_option} =
      attrs
      |> Enum.into(%{
        body: "some body",
        is_correct: true
      })
      |> Quizir.Quizzes.create_answer_option()

    answer_option
  end
end
