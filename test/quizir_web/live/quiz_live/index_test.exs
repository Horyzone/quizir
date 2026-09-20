defmodule QuizirWeb.QuizLive.IndexTest do
  use QuizirWeb.ConnCase

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
  end
end
