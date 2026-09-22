defmodule QuizirWeb.QuizLive.ShowTest do
  use QuizirWeb.ConnCase

  alias Quizir.Quizzes
  import Quizir.AccountsFixtures

  defp create_detailed_quiz(attrs \\ %{}, user \\ nil) do
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
      |> Quizzes.create_quiz(user)

    quiz
  end

  describe "GET /quizzes/:id (Show) as owner" do
    setup :register_and_log_in_user

    test "renders owner buttons (edit, delete, start)", %{conn: conn, user: user} do
      quiz = create_detailed_quiz(%{}, user)

      {:ok, view, _html} = live(conn, ~p"/quizzes/#{quiz}")

      assert has_element?(view, "#quiz-details-card")
      assert has_element?(view, "#quiz-details-title", quiz.title)
      assert has_element?(view, "#edit-quiz-btn")
      assert has_element?(view, "#delete-quiz-btn")
      refute has_element?(view, "#duplicate-quiz-btn")
      assert has_element?(view, "#start-game-btn")

      # Questions and options are listed
      assert has_element?(view, "#show-question-card-#{hd(quiz.questions).id}")
      assert has_element?(view, "#questions-list", "Qui a réalisé Inception ?")
    end

    test "deletes quiz and redirects to index", %{conn: conn, user: user} do
      quiz = create_detailed_quiz(%{}, user)

      {:ok, view, _html} = live(conn, ~p"/quizzes/#{quiz}")

      {:ok, _index_live, html} =
        view
        |> element("#delete-quiz-btn")
        |> render_click()
        |> follow_redirect(conn, ~p"/quizzes")

      assert html =~ "Quiz « Quiz Cinéma » supprimé avec succès."
      assert_raise Ecto.NoResultsError, fn -> Quizzes.get_quiz!(quiz.id) end
    end
  end

  describe "GET /quizzes/:id (Show) as non-owner" do
    test "visitor sees duplicate button instead of edit and delete", %{conn: conn} do
      owner = user_fixture()
      quiz = create_detailed_quiz(%{}, owner)

      {:ok, view, _html} = live(conn, ~p"/quizzes/#{quiz}")

      assert has_element?(view, "#duplicate-quiz-btn")
      refute has_element?(view, "#edit-quiz-btn")
      refute has_element?(view, "#delete-quiz-btn")
      assert has_element?(view, "#start-game-btn")
      assert has_element?(view, "#quiz-author-badge", owner.username)
    end

    test "unauthenticated duplication redirects to login", %{conn: conn} do
      owner = user_fixture()
      quiz = create_detailed_quiz(%{}, owner)

      {:ok, view, _html} = live(conn, ~p"/quizzes/#{quiz}")

      {:ok, _view, html} =
        view
        |> element("#duplicate-quiz-btn")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log_in")

      assert html =~ "Vous devez être connecté pour dupliquer un quiz."
    end

    test "authenticated non-owner can duplicate quiz into their own", %{conn: conn} do
      owner = user_fixture()
      quiz = create_detailed_quiz(%{}, owner)

      logged_user = user_fixture()
      logged_conn = log_in_user(conn, logged_user)

      {:ok, view, _html} = live(logged_conn, ~p"/quizzes/#{quiz}")

      {:ok, edit_view, html} =
        view
        |> element("#duplicate-quiz-btn")
        |> render_click()
        |> follow_redirect(logged_conn)

      assert html =~ "Quiz dupliqué avec succès !"
      assert has_element?(edit_view, "#quiz-title[value='Quiz Cinéma (copie)']")

      # Verify the duplicate is owned by logged_user
      duplicate =
        Quizzes.list_quizzes()
        |> Enum.find(&(&1.title == "Quiz Cinéma (copie)"))

      assert duplicate != nil
      assert duplicate.user_id == logged_user.id
      detailed_duplicate = Quizzes.get_quiz_with_details!(duplicate.id)
      assert length(detailed_duplicate.questions) == 2
    end
  end

  describe "GET /quizzes/:id (General Show interactions)" do
    test "renders private notice for private quiz", %{conn: conn} do
      quiz = create_detailed_quiz(%{visibility: "private"})

      {:ok, view, _html} = live(conn, ~p"/quizzes/#{quiz}")

      assert has_element?(view, "#quiz-details-card", "Quiz privé")
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
