defmodule QuizirWeb.QuizLive.IndexTest do
  use QuizirWeb.ConnCase

  alias Quizir.Quizzes
  import Quizir.QuizzesFixtures

  describe "GET /quizzes" do
    test "renders empty state when there are no quizzes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes")

      assert has_element?(view, "#empty-quizzes-state")
      assert has_element?(view, "#new-quiz-button")
    end

    test "renders quizzes stream when quizzes exist", %{conn: conn} do
      quiz = quiz_fixture(%{title: "Cinéma Français", visibility: "public"})
      {:ok, view, _html} = live(conn, ~p"/quizzes")

      assert has_element?(view, "#quizzes")
      assert has_element?(view, "#quizzes-#{quiz.id}")
    end

    test "navigates to /quizzes/new when clicking Nouveau Quiz", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes")

      {:ok, _form_live, html} =
        view
        |> element("#new-quiz-button")
        |> render_click()
        |> follow_redirect(conn, ~p"/quizzes/new")

      assert html =~ "Créer un Quiz"
    end

    test "navigates to quiz show page when clicking Voir les détails", %{conn: conn} do
      quiz = quiz_fixture(%{title: "Cinéma Français", visibility: "public"})
      {:ok, view, _html} = live(conn, ~p"/quizzes")

      {:ok, _show_live, html} =
        view
        |> element("#view-quiz-#{quiz.id}-btn")
        |> render_click()
        |> follow_redirect(conn, ~p"/quizzes/#{quiz}")

      assert html =~ "Cinéma Français"
    end

    test "navigates to edit page when clicking Modifier", %{conn: conn} do
      quiz = quiz_fixture(%{title: "Cinéma Français", visibility: "public"})
      {:ok, view, _html} = live(conn, ~p"/quizzes")

      {:ok, _edit_live, html} =
        view
        |> element("#edit-quiz-#{quiz.id}-btn")
        |> render_click()
        |> follow_redirect(conn, ~p"/quizzes/#{quiz}/edit")

      assert html =~ "Modifier le Quiz"
    end

    test "deletes quiz from stream and database when clicking delete", %{conn: conn} do
      quiz = quiz_fixture(%{title: "Quiz à supprimer", visibility: "public"})
      {:ok, view, _html} = live(conn, ~p"/quizzes")

      assert has_element?(view, "#quizzes-#{quiz.id}")

      view
      |> element("#delete-quiz-#{quiz.id}-btn")
      |> render_click()

      refute has_element?(view, "#quizzes-#{quiz.id}")
      assert_raise Ecto.NoResultsError, fn -> Quizzes.get_quiz!(quiz.id) end
    end
  end
end
