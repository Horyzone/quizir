defmodule QuizirWeb.QuizLive.FormTest do
  use QuizirWeb.ConnCase

  alias Quizir.Quizzes

  @valid_quiz_params %{
    "title" => "Quiz sur la Géographie",
    "description" => "Un test de connaissances géographiques",
    "visibility" => "public",
    "access_code" => "",
    "questions" => %{
      "0" => %{
        "body" => "Quelle est la capitale de l'Australie ?",
        "time_limit_seconds" => "30",
        "answer_options" => %{
          "0" => %{"body" => "Canberra", "is_correct" => "true"},
          "1" => %{"body" => "Sydney", "is_correct" => "false"}
        }
      }
    }
  }

  describe "GET /quizzes/new" do
    test "renders creation form, layout, and default question", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      assert has_element?(view, "#quiz-form")
      assert has_element?(view, "#quiz-title")
      assert has_element?(view, "#quiz-description")
      assert has_element?(view, "#quiz-visibility")
      assert has_element?(view, "#quiz-access-code")
      assert has_element?(view, "#question-card-0")
      assert has_element?(view, "#question-0-body")
      assert has_element?(view, "#question-0-time-limit")
      assert has_element?(view, "#question-0-option-0")
      assert has_element?(view, "#question-0-option-1")
      assert has_element?(view, "#add-question-btn")
      assert has_element?(view, "#save-quiz-button")
    end

    test "validates required fields on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      response =
        view
        |> form("#quiz-form", quiz: %{"title" => ""})
        |> render_change()

      assert response =~ "can&#39;t be blank"
    end

    test "validates access_code when visibility is private", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      response =
        view
        |> form("#quiz-form", quiz: %{"visibility" => "private", "access_code" => ""})
        |> render_change()

      assert response =~ "can&#39;t be blank"
    end

    test "validates time limit boundary (greater than 4, less than 121)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      response =
        view
        |> form("#quiz-form",
          quiz: %{
            "questions" => %{
              "0" => %{"time_limit_seconds" => "3"}
            }
          }
        )
        |> render_change()

      assert response =~ "must be greater than 4"
    end

    test "can dynamically add and remove questions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      # Initially 1 question
      assert has_element?(view, "#question-card-0")
      refute has_element?(view, "#question-card-1")

      # Add question
      view
      |> element("#add-question-btn")
      |> render_click()

      assert has_element?(view, "#question-card-0")
      assert has_element?(view, "#question-card-1")

      # Remove second question
      view
      |> element("#remove-question-1-btn")
      |> render_click()

      assert has_element?(view, "#question-card-0")
      refute has_element?(view, "#question-card-1")

      # Attempting to remove the only remaining question keeps it
      view
      |> element("#remove-question-0-btn")
      |> render_click()

      assert has_element?(view, "#question-card-0")
    end

    test "can dynamically add and remove answer options", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      # Initially 2 options in question 0
      assert has_element?(view, "#question-0-option-0")
      assert has_element?(view, "#question-0-option-1")
      refute has_element?(view, "#question-0-option-2")

      # Add option
      view
      |> element("#add-option-0-btn")
      |> render_click()

      assert has_element?(view, "#question-0-option-2")

      # Remove option 2
      view
      |> element("#remove-option-0-2-btn")
      |> render_click()

      refute has_element?(view, "#question-0-option-2")

      # Removing when 2 options remain preserves at least 2 options
      view
      |> element("#remove-option-0-1-btn")
      |> render_click()

      assert has_element?(view, "#question-0-option-0")
      assert has_element?(view, "#question-0-option-1")
    end

    test "creates quiz and redirects to index on valid submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      {:ok, _index_live, html} =
        view
        |> form("#quiz-form", quiz: @valid_quiz_params)
        |> render_submit()
        |> follow_redirect(conn, ~p"/quizzes")

      assert html =~ "Quiz « Quiz sur la Géographie » créé avec succès !"

      # Vérification en base de données
      [quiz] = Quizzes.list_quizzes()
      assert quiz.title == "Quiz sur la Géographie"
      quiz_details = Quizzes.get_quiz_with_details!(quiz.id)
      assert length(quiz_details.questions) == 1
      [question] = quiz_details.questions
      assert question.body == "Quelle est la capitale de l'Australie ?"
      assert length(question.answer_options) == 2
    end

    test "creates a private quiz with access code", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      private_params =
        @valid_quiz_params
        |> Map.put("title", "Quiz VIP")
        |> Map.put("visibility", "private")
        |> Map.put("access_code", "SECRET123")

      {:ok, _index_live, _html} =
        view
        |> form("#quiz-form", quiz: private_params)
        |> render_submit()
        |> follow_redirect(conn, ~p"/quizzes")

      [quiz] = Enum.filter(Quizzes.list_quizzes(), &(&1.title == "Quiz VIP"))
      assert quiz.visibility == "private"
      assert quiz.access_code == "SECRET123"
    end

    test "renders errors when submitting invalid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      response =
        view
        |> form("#quiz-form", quiz: %{"title" => ""})
        |> render_submit()

      assert response =~ "can&#39;t be blank"
    end

    test "navigates back to quizzes index via back button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      {:ok, _index_live, html} =
        view
        |> element("#back-button")
        |> render_click()
        |> follow_redirect(conn, ~p"/quizzes")

      assert html =~ "Quiz disponibles"
    end
  end
end
