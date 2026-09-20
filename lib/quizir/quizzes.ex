defmodule Quizir.Quizzes do
  @moduledoc """
  The Quizzes context.
  """

  import Ecto.Query, warn: false
  alias Quizir.Repo

  alias Quizir.Quizzes.Quiz

  @doc """
  Returns the list of quizzes.

  ## Examples

      iex> list_quizzes()
      [%Quiz{}, ...]

  """
  def list_quizzes do
    Repo.all(Quiz)
  end

  @doc """
  Gets a single quiz.

  Raises `Ecto.NoResultsError` if the Quiz does not exist.

  ## Examples

      iex> get_quiz!(123)
      %Quiz{}

      iex> get_quiz!(456)
      ** (Ecto.NoResultsError)

  """
  def get_quiz!(id), do: Repo.get!(Quiz, id)

  def get_quiz_with_details!(id) do
    import Ecto.Query

    Quizir.Repo.one!(
      from q in Quizir.Quizzes.Quiz,
        where: q.id == ^id,
        preload: [questions: :answer_options]
    )
  end

  @doc """
  Creates a quiz.

  ## Examples

      iex> create_quiz(%{field: value})
      {:ok, %Quiz{}}

      iex> create_quiz(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_quiz(attrs) do
    %Quiz{}
    |> Quiz.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a quiz.

  ## Examples

      iex> update_quiz(quiz, %{field: new_value})
      {:ok, %Quiz{}}

      iex> update_quiz(quiz, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_quiz(%Quiz{} = quiz, attrs) do
    quiz
    |> Quiz.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a quiz.

  ## Examples

      iex> delete_quiz(quiz)
      {:ok, %Quiz{}}

      iex> delete_quiz(quiz)
      {:error, %Ecto.Changeset{}}

  """
  def delete_quiz(%Quiz{} = quiz) do
    Repo.delete(quiz)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking quiz changes.

  ## Examples

      iex> change_quiz(quiz)
      %Ecto.Changeset{data: %Quiz{}}

  """
  def change_quiz(%Quiz{} = quiz, attrs \\ %{}) do
    Quiz.changeset(quiz, attrs)
  end

  alias Quizir.Quizzes.Question

  @doc """
  Returns the list of questions.

  ## Examples

      iex> list_questions()
      [%Question{}, ...]

  """
  def list_questions do
    Repo.all(Question)
  end

  @doc """
  Gets a single question.

  Raises `Ecto.NoResultsError` if the Question does not exist.

  ## Examples

      iex> get_question!(123)
      %Question{}

      iex> get_question!(456)
      ** (Ecto.NoResultsError)

  """
  def get_question!(id), do: Repo.get!(Question, id)

  @doc """
  Creates a question.

  ## Examples

      iex> create_question(%{field: value})
      {:ok, %Question{}}

      iex> create_question(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_question(attrs) do
    %Question{}
    |> Question.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a question.

  ## Examples

      iex> update_question(question, %{field: new_value})
      {:ok, %Question{}}

      iex> update_question(question, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_question(%Question{} = question, attrs) do
    question
    |> Question.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a question.

  ## Examples

      iex> delete_question(question)
      {:ok, %Question{}}

      iex> delete_question(question)
      {:error, %Ecto.Changeset{}}

  """
  def delete_question(%Question{} = question) do
    Repo.delete(question)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking question changes.

  ## Examples

      iex> change_question(question)
      %Ecto.Changeset{data: %Question{}}

  """
  def change_question(%Question{} = question, attrs \\ %{}) do
    Question.changeset(question, attrs)
  end

  alias Quizir.Quizzes.AnswerOption

  @doc """
  Returns the list of answer_options.

  ## Examples

      iex> list_answer_options()
      [%AnswerOption{}, ...]

  """
  def list_answer_options do
    Repo.all(AnswerOption)
  end

  @doc """
  Gets a single answer_option.

  Raises `Ecto.NoResultsError` if the Answer option does not exist.

  ## Examples

      iex> get_answer_option!(123)
      %AnswerOption{}

      iex> get_answer_option!(456)
      ** (Ecto.NoResultsError)

  """
  def get_answer_option!(id), do: Repo.get!(AnswerOption, id)

  @doc """
  Creates a answer_option.

  ## Examples

      iex> create_answer_option(%{field: value})
      {:ok, %AnswerOption{}}

      iex> create_answer_option(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_answer_option(attrs) do
    %AnswerOption{}
    |> AnswerOption.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a answer_option.

  ## Examples

      iex> update_answer_option(answer_option, %{field: new_value})
      {:ok, %AnswerOption{}}

      iex> update_answer_option(answer_option, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_answer_option(%AnswerOption{} = answer_option, attrs) do
    answer_option
    |> AnswerOption.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a answer_option.

  ## Examples

      iex> delete_answer_option(answer_option)
      {:ok, %AnswerOption{}}

      iex> delete_answer_option(answer_option)
      {:error, %Ecto.Changeset{}}

  """
  def delete_answer_option(%AnswerOption{} = answer_option) do
    Repo.delete(answer_option)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking answer_option changes.

  ## Examples

      iex> change_answer_option(answer_option)
      %Ecto.Changeset{data: %AnswerOption{}}

  """
  def change_answer_option(%AnswerOption{} = answer_option, attrs \\ %{}) do
    AnswerOption.changeset(answer_option, attrs)
  end
end
