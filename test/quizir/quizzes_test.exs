defmodule Quizir.QuizzesTest do
  use Quizir.DataCase

  alias Quizir.Quizzes

  describe "quizzes" do
    alias Quizir.Quizzes.Quiz

    import Quizir.QuizzesFixtures

    @invalid_attrs %{description: nil, title: nil, visibility: nil, access_code: nil}

    test "list_quizzes/0 returns all quizzes" do
      quiz = quiz_fixture()
      assert Quizzes.list_quizzes() == [quiz]
    end

    test "get_quiz!/1 returns the quiz with given id" do
      quiz = quiz_fixture()
      assert Quizzes.get_quiz!(quiz.id) == quiz
    end

    test "create_quiz/1 with valid data creates a quiz" do
      valid_attrs = %{description: "some description", title: "some title", visibility: "some visibility", access_code: "some access_code"}

      assert {:ok, %Quiz{} = quiz} = Quizzes.create_quiz(valid_attrs)
      assert quiz.description == "some description"
      assert quiz.title == "some title"
      assert quiz.visibility == "some visibility"
      assert quiz.access_code == "some access_code"
    end

    test "create_quiz/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Quizzes.create_quiz(@invalid_attrs)
    end

    test "update_quiz/2 with valid data updates the quiz" do
      quiz = quiz_fixture()
      update_attrs = %{description: "some updated description", title: "some updated title", visibility: "some updated visibility", access_code: "some updated access_code"}

      assert {:ok, %Quiz{} = quiz} = Quizzes.update_quiz(quiz, update_attrs)
      assert quiz.description == "some updated description"
      assert quiz.title == "some updated title"
      assert quiz.visibility == "some updated visibility"
      assert quiz.access_code == "some updated access_code"
    end

    test "update_quiz/2 with invalid data returns error changeset" do
      quiz = quiz_fixture()
      assert {:error, %Ecto.Changeset{}} = Quizzes.update_quiz(quiz, @invalid_attrs)
      assert quiz == Quizzes.get_quiz!(quiz.id)
    end

    test "delete_quiz/1 deletes the quiz" do
      quiz = quiz_fixture()
      assert {:ok, %Quiz{}} = Quizzes.delete_quiz(quiz)
      assert_raise Ecto.NoResultsError, fn -> Quizzes.get_quiz!(quiz.id) end
    end

    test "change_quiz/1 returns a quiz changeset" do
      quiz = quiz_fixture()
      assert %Ecto.Changeset{} = Quizzes.change_quiz(quiz)
    end
  end

  describe "questions" do
    alias Quizir.Quizzes.Question

    import Quizir.QuizzesFixtures

    @invalid_attrs %{body: nil, order: nil, time_limit_seconds: nil}

    test "list_questions/0 returns all questions" do
      question = question_fixture()
      assert Quizzes.list_questions() == [question]
    end

    test "get_question!/1 returns the question with given id" do
      question = question_fixture()
      assert Quizzes.get_question!(question.id) == question
    end

    test "create_question/1 with valid data creates a question" do
      valid_attrs = %{body: "some body", order: 42, time_limit_seconds: 42}

      assert {:ok, %Question{} = question} = Quizzes.create_question(valid_attrs)
      assert question.body == "some body"
      assert question.order == 42
      assert question.time_limit_seconds == 42
    end

    test "create_question/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Quizzes.create_question(@invalid_attrs)
    end

    test "update_question/2 with valid data updates the question" do
      question = question_fixture()
      update_attrs = %{body: "some updated body", order: 43, time_limit_seconds: 43}

      assert {:ok, %Question{} = question} = Quizzes.update_question(question, update_attrs)
      assert question.body == "some updated body"
      assert question.order == 43
      assert question.time_limit_seconds == 43
    end

    test "update_question/2 with invalid data returns error changeset" do
      question = question_fixture()
      assert {:error, %Ecto.Changeset{}} = Quizzes.update_question(question, @invalid_attrs)
      assert question == Quizzes.get_question!(question.id)
    end

    test "delete_question/1 deletes the question" do
      question = question_fixture()
      assert {:ok, %Question{}} = Quizzes.delete_question(question)
      assert_raise Ecto.NoResultsError, fn -> Quizzes.get_question!(question.id) end
    end

    test "change_question/1 returns a question changeset" do
      question = question_fixture()
      assert %Ecto.Changeset{} = Quizzes.change_question(question)
    end
  end

  describe "answer_options" do
    alias Quizir.Quizzes.AnswerOption

    import Quizir.QuizzesFixtures

    @invalid_attrs %{body: nil, is_correct: nil}

    test "list_answer_options/0 returns all answer_options" do
      answer_option = answer_option_fixture()
      assert Quizzes.list_answer_options() == [answer_option]
    end

    test "get_answer_option!/1 returns the answer_option with given id" do
      answer_option = answer_option_fixture()
      assert Quizzes.get_answer_option!(answer_option.id) == answer_option
    end

    test "create_answer_option/1 with valid data creates a answer_option" do
      valid_attrs = %{body: "some body", is_correct: true}

      assert {:ok, %AnswerOption{} = answer_option} = Quizzes.create_answer_option(valid_attrs)
      assert answer_option.body == "some body"
      assert answer_option.is_correct == true
    end

    test "create_answer_option/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Quizzes.create_answer_option(@invalid_attrs)
    end

    test "update_answer_option/2 with valid data updates the answer_option" do
      answer_option = answer_option_fixture()
      update_attrs = %{body: "some updated body", is_correct: false}

      assert {:ok, %AnswerOption{} = answer_option} = Quizzes.update_answer_option(answer_option, update_attrs)
      assert answer_option.body == "some updated body"
      assert answer_option.is_correct == false
    end

    test "update_answer_option/2 with invalid data returns error changeset" do
      answer_option = answer_option_fixture()
      assert {:error, %Ecto.Changeset{}} = Quizzes.update_answer_option(answer_option, @invalid_attrs)
      assert answer_option == Quizzes.get_answer_option!(answer_option.id)
    end

    test "delete_answer_option/1 deletes the answer_option" do
      answer_option = answer_option_fixture()
      assert {:ok, %AnswerOption{}} = Quizzes.delete_answer_option(answer_option)
      assert_raise Ecto.NoResultsError, fn -> Quizzes.get_answer_option!(answer_option.id) end
    end

    test "change_answer_option/1 returns a answer_option changeset" do
      answer_option = answer_option_fixture()
      assert %Ecto.Changeset{} = Quizzes.change_answer_option(answer_option)
    end
  end
end
