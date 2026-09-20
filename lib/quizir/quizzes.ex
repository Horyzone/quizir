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
    from(q in Quiz, order_by: [desc: q.inserted_at, desc: q.id], preload: [:user])
    |> Repo.all()
  end

  @doc """
  Returns the list of quizzes created by a specific user with an optional visibility filter.
  Allowed filter values: "all", "public", "private" (or atoms :all, :public, :private).
  """
  def list_user_quizzes(user, filter \\ "all")

  def list_user_quizzes(%Quizir.Accounts.User{id: user_id}, filter) do
    list_user_quizzes(user_id, filter)
  end

  def list_user_quizzes(user_id, filter) do
    query =
      from q in Quiz,
        where: q.user_id == ^user_id,
        order_by: [desc: q.inserted_at, desc: q.id],
        preload: [:user, :questions]

    query =
      case to_string(filter) do
        "public" -> from q in query, where: q.visibility == "public"
        "private" -> from q in query, where: q.visibility == "private"
        _ -> query
      end

    Repo.all(query)
  end

  @doc """
  Returns quiz counts (total, public, private) for a given user.
  """
  def count_user_quizzes_by_visibility(%Quizir.Accounts.User{id: user_id}) do
    count_user_quizzes_by_visibility(user_id)
  end

  def count_user_quizzes_by_visibility(user_id) do
    counts =
      from(q in Quiz,
        where: q.user_id == ^user_id,
        group_by: q.visibility,
        select: {q.visibility, count(q.id)}
      )
      |> Repo.all()
      |> Map.new()

    public_count = Map.get(counts, "public", 0)
    private_count = Map.get(counts, "private", 0)

    %{
      total: public_count + private_count,
      public: public_count,
      private: private_count
    }
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
  def get_quiz!(id) do
    from(q in Quiz, where: q.id == ^id, preload: [:user])
    |> Repo.one!()
  end

  def get_quiz_with_details!(id) do
    questions_query = from q in Quizir.Quizzes.Question, order_by: [asc: q.order, asc: q.id]
    options_query = from o in Quizir.Quizzes.AnswerOption, order_by: [asc: o.id]

    Repo.one!(
      from q in Quiz,
        where: q.id == ^id,
        preload: [:user, questions: ^{questions_query, answer_options: options_query}]
    )
  end

  @doc """
  Checks if a user can manage (modify or delete) a quiz.
  """
  def can_manage_quiz?(%Quiz{user_id: user_id}, %Quizir.Accounts.User{id: current_user_id}) do
    user_id != nil and user_id == current_user_id
  end

  def can_manage_quiz?(_quiz, _user), do: false

  @doc """
  Duplicates a quiz with all its questions and answer options for a new owner.
  """
  def duplicate_quiz(%Quiz{} = source_quiz, %Quizir.Accounts.User{} = user) do
    quiz = get_quiz_with_details!(source_quiz.id)

    duplicated_questions =
      Enum.map(quiz.questions || [], fn q ->
        options =
          Enum.map(q.answer_options || [], fn opt ->
            %{
              "body" => opt.body,
              "is_correct" => opt.is_correct
            }
          end)

        %{
          "body" => q.body,
          "order" => q.order,
          "time_limit_seconds" => q.time_limit_seconds,
          "answer_options" => options
        }
      end)

    attrs = %{
      "title" => "#{quiz.title} (copie)",
      "description" => quiz.description,
      "visibility" => quiz.visibility,
      "access_code" => quiz.access_code,
      "questions" => duplicated_questions
    }

    create_quiz(attrs, user)
  end

  def duplicate_quiz(quiz_id, %Quizir.Accounts.User{} = user) do
    quiz = get_quiz_with_details!(quiz_id)
    duplicate_quiz(quiz, user)
  end

  @doc """
  Creates a quiz optionally associated with an owner user.
  """
  def create_quiz(attrs, user \\ nil) do
    quiz = if user, do: %Quiz{user_id: user.id}, else: %Quiz{}

    quiz
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
