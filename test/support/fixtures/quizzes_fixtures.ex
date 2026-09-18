defmodule Quizir.QuizzesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Quizir.Quizzes` context.
  """

  @doc """
  Generate a quiz.
  """
  def quiz_fixture(attrs \\ %{}) do
    {:ok, quiz} =
      attrs
      |> Enum.into(%{
        access_code: "some access_code",
        description: "some description",
        title: "some title",
        visibility: "some visibility"
      })
      |> Quizir.Quizzes.create_quiz()

    quiz
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
