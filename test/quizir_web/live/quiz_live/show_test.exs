defmodule QuizirWeb.QuizLive.ShowTest do
  use QuizirWeb.ConnCase

  alias Quizir.Quizzes

  defp create_detailed_quiz(attrs \\ %{}) do
    default_attrs = %{
      title: "Quiz Cinéma",
      description: "Le quiz des cinéphiles",
      visibility: "public",
      questions: [
        %{
          body: "Qui a réalisé Inception ?",
          order: 1,
          time_limit_seconds: 25,
          answer_options: [
            %{body: "Christopher Nolan", is_correct: true},
            %{body: "Steven Spielberg", is_correct: false}
          ]
        },
        %{
          body: "En quelle année est sorti Matrix ?",
          order: 2,
          time_limit_seconds: 20,
          answer_options: [
            %{body: "1999", is_correct: true},
            %{body: "2001", is_correct: false}
          ]
        }
      ]
    }

    {:ok, quiz} =
      default_attrs
      |> Map.merge(attrs)
      |> Quizzes.create_quiz()

    quiz
  end

  describe "GET /quizzes/:id (Show)" do
    test "renders quiz details, questions, and options", %{conn: conn} do
      quiz = create_detailed_quiz()

      {:ok, view, _html} = live(conn, ~p"/quizzes/#{quiz}")

      assert has_element?(view, "#quiz-details-card")
      assert has_element?(view, "#quiz-details-title", quiz.title)
      assert has_element?(view, "#quiz-details-desc", quiz.description)
      assert has_element?(view, "#edit-quiz-btn")
      assert has_element?(view, "#delete-quiz-btn")
      assert has_element?(view, "#start-game-btn")

      # Questions and options are listed
      assert has_element?(view, "#show-question-card-#{hd(quiz.questions).id}")
      assert has_element?(view, "#questions-list", "Qui a réalisé Inception ?")
      assert has_element?(view, "#questions-list", "Christopher Nolan")
      assert has_element?(view, "#questions-list", "Matrix")
    end

    test "renders access code badge for private quiz", %{conn: conn} do
      quiz = create_detailed_quiz(%{visibility: "private", access_code: "VIP99"})

      {:ok, view, _html} = live(conn, ~p"/quizzes/#{quiz}")

      assert has_element?(view, "#quiz-access-code-badge", "VIP99")
    end

    test "deletes quiz and redirects to index", %{conn: conn} do
      quiz = create_detailed_quiz()

      {:ok, view, _html} = live(conn, ~p"/quizzes/#{quiz}")

      {:ok, _index_live, html} =
        view
        |> element("#delete-quiz-btn")
        |> render_click()
        |> follow_redirect(conn, ~p"/quizzes")

      assert html =~ "Quiz « Quiz Cinéma » supprimé avec succès."
      assert_raise Ecto.NoResultsError, fn -> Quizzes.get_quiz!(quiz.id) end
    end

    test "clicks start game button and redirects to game lobby", %{conn: conn} do
      quiz = create_detailed_quiz()

      {:ok, view, _html} = live(conn, ~p"/quizzes/#{quiz}")

      {:ok, game_live, _html} =
        view
        |> element("#start-game-btn")
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(game_live, "#host-badge")
      assert has_element?(game_live, "#host-start-game-btn")
      assert has_element?(game_live, "#lobby-screen")
    end

    test "navigates back to index", %{conn: conn} do
      quiz = create_detailed_quiz()

      {:ok, view, _html} = live(conn, ~p"/quizzes/#{quiz}")

      {:ok, _index_live, html} =
        view
        |> element("#back-to-quizzes-btn")
        |> render_click()
        |> follow_redirect(conn, ~p"/quizzes")

      assert html =~ "Quiz disponibles"
    end
  end
end
