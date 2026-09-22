defmodule QuizirWeb.QuizLive.IndexTest do
  use QuizirWeb.ConnCase

  alias Quizir.Quizzes
  import Quizir.QuizzesFixtures
  import Quizir.AccountsFixtures

  describe "GET /quizzes (unauthenticated)" do
    test "renders empty state when there are no quizzes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes")

      assert has_element?(view, "#empty-quizzes-state")
      assert has_element?(view, "#new-quiz-button")
    end

    test "renders quizzes stream and duplicate button for non-owner", %{conn: conn} do
      owner = user_fixture()
      quiz = quiz_fixture(%{title: "Cinéma Français", visibility: "public", user_id: owner.id})
      {:ok, view, _html} = live(conn, ~p"/quizzes")

      assert has_element?(view, "#quizzes")
      assert has_element?(view, "#quizzes-#{quiz.id}")
      assert has_element?(view, "#duplicate-quiz-#{quiz.id}-btn")
      refute has_element?(view, "#edit-quiz-#{quiz.id}-btn")
      refute has_element?(view, "#delete-quiz-#{quiz.id}-btn")
    end

    test "does not render private quizzes in public list", %{conn: conn} do
      owner = user_fixture()

      pub_quiz =
        quiz_fixture(%{title: "Quiz Public Explorateur", visibility: "public", user_id: owner.id})

      priv_quiz =
        quiz_fixture(%{title: "Quiz Privé Secret", visibility: "private", user_id: owner.id})

      {:ok, view, _html} = live(conn, ~p"/quizzes")

      assert has_element?(view, "#quizzes-#{pub_quiz.id}")
      refute has_element?(view, "#quizzes-#{priv_quiz.id}")
      refute has_element?(view, "h1, a, span, p", "Quiz Privé Secret")
    end

    test "navigates to /quizzes/new and redirects to login when clicking Nouveau Quiz unauthenticated",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes")

      assert {:error, {:redirect, %{to: "/users/log_in", flash: flash}}} =
               view
               |> element("#new-quiz-button")
               |> render_click()
               |> follow_redirect(conn, ~p"/quizzes/new")

      assert flash["error"] =~ "Vous devez être connecté"
    end
  end

  describe "GET /quizzes (authenticated owner)" do
    setup :register_and_log_in_user

    test "navigates to /quizzes/new when clicking Nouveau Quiz", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes")

      {:ok, _form_live, html} =
        view
        |> element("#new-quiz-button")
        |> render_click()
        |> follow_redirect(conn, ~p"/quizzes/new")

      assert html =~ "Créer un Quiz"
    end

    test "owner sees edit and delete buttons and can edit", %{conn: conn, user: user} do
      quiz = quiz_fixture(%{title: "Mon Quiz Perso", visibility: "public", user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/quizzes")

      assert has_element?(view, "#edit-quiz-#{quiz.id}-btn")
      assert has_element?(view, "#delete-quiz-#{quiz.id}-btn")

      {:ok, _edit_live, html} =
        view
        |> element("#edit-quiz-#{quiz.id}-btn")
        |> render_click()
        |> follow_redirect(conn, ~p"/quizzes/#{quiz}/edit")

      assert html =~ "Modifier le Quiz"
    end

    test "owner can delete quiz from stream and database", %{conn: conn, user: user} do
      quiz = quiz_fixture(%{title: "Quiz à supprimer", visibility: "public", user_id: user.id})
      {:ok, view, _html} = live(conn, ~p"/quizzes")

      assert has_element?(view, "#quizzes-#{quiz.id}")

      view
      |> element("#delete-quiz-#{quiz.id}-btn")
      |> render_click()

      refute has_element?(view, "#quizzes-#{quiz.id}")
      assert_raise Ecto.NoResultsError, fn -> Quizzes.get_quiz!(quiz.id) end
    end

    test "authenticated user can duplicate another user's quiz from index", %{conn: conn} do
      other_user = user_fixture()
      quiz = quiz_fixture(%{title: "Quiz Culture", visibility: "public", user_id: other_user.id})

      {:ok, view, _html} = live(conn, ~p"/quizzes")

      {:ok, _edit_live, html} =
        view
        |> element("#duplicate-quiz-#{quiz.id}-btn")
        |> render_click()
        |> follow_redirect(conn)

      assert html =~ "Quiz dupliqué avec succès !"
    end

    test "user can start public game directly from quiz card", %{conn: conn} do
      owner = user_fixture()
      quiz = quiz_fixture(%{title: "Quiz Direct Play", visibility: "public", user_id: owner.id})

      {:ok, view, _html} = live(conn, ~p"/quizzes")

      assert has_element?(view, "#start-game-btn-#{quiz.id}")
      assert has_element?(view, "#launch-public-session-btn-#{quiz.id}")

      {:ok, game_live, _html} =
        view
        |> element("#launch-public-session-btn-#{quiz.id}")
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(game_live, "#host-badge")
      assert has_element?(game_live, "#lobby-screen")
    end

    test "user can start private game directly from quiz card dropdown", %{conn: conn} do
      owner = user_fixture()
      quiz = quiz_fixture(%{title: "Quiz Secret Direct", visibility: "public", user_id: owner.id})

      {:ok, view, _html} = live(conn, ~p"/quizzes")

      assert has_element?(view, "#launch-private-session-btn-#{quiz.id}")

      {:ok, game_live, _html} =
        view
        |> element("#launch-private-session-btn-#{quiz.id}")
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(game_live, "#host-badge")
      assert has_element?(game_live, "#lobby-screen")
    end
  end
end
