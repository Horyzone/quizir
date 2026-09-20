defmodule QuizirWeb.QuizLive.FormTest do
  use QuizirWeb.ConnCase

  alias Quizir.Quizzes
  import Quizir.AccountsFixtures

  @valid_quiz_params %{
    "title" => "Quiz sur la Géographie",
    "description" => "Un test de connaissances géographiques",
    "visibility" => "public",
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

  describe "GET /quizzes/new (unauthenticated)" do
    test "redirects unauthenticated users to login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, ~p"/quizzes/new")
    end
  end

  describe "GET /quizzes/new (authenticated)" do
    setup :register_and_log_in_user

    test "renders creation form, layout, and default question", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      assert has_element?(view, "#quiz-form")
      assert has_element?(view, "#quiz-title")
      assert has_element?(view, "#quiz-description")
      assert has_element?(view, "#quiz-visibility")
      refute has_element?(view, "#quiz-access-code")
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

    test "private quiz does not require access_code", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      response =
        view
        |> form("#quiz-form", quiz: Map.put(@valid_quiz_params, "visibility", "private"))
        |> render_change()

      refute response =~ "can&#39;t be blank"
    end

    test "validates time limit boundary (greater than 4, less than 121)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      params_low = %{
        "questions" => %{
          "0" => %{"time_limit_seconds" => "3"}
        }
      }

      response_low =
        view
        |> form("#quiz-form", quiz: params_low)
        |> render_change()

      assert response_low =~ "must be greater than 4"

      params_high = %{
        "questions" => %{
          "0" => %{"time_limit_seconds" => "130"}
        }
      }

      response_high =
        view
        |> form("#quiz-form", quiz: params_high)
        |> render_change()

      assert response_high =~ "must be less than 121"
    end

    test "can dynamically add and remove questions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      assert has_element?(view, "#question-card-0")
      refute has_element?(view, "#question-card-1")

      view
      |> element("#add-question-btn")
      |> render_click()

      assert has_element?(view, "#question-card-0")
      assert has_element?(view, "#question-card-1")

      view
      |> element("#remove-question-1-btn")
      |> render_click()

      assert has_element?(view, "#question-card-0")
      refute has_element?(view, "#question-card-1")
    end

    test "can add and remove answer options from a question", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      assert has_element?(view, "#question-0-option-0")
      assert has_element?(view, "#question-0-option-1")
      refute has_element?(view, "#question-0-option-2")

      view
      |> element("#add-option-0-btn")
      |> render_click()

      assert has_element?(view, "#question-0-option-2")

      view
      |> element("#remove-option-0-2-btn")
      |> render_click()

      refute has_element?(view, "#question-0-option-2")
    end

    test "cannot remove answer option below minimum of 2", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      refute has_element?(view, "#remove-option-btn-0-0")
      refute has_element?(view, "#remove-option-btn-0-1")
    end

    test "cannot remove the only question", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      refute has_element?(view, "#remove-question-0-btn")
    end

    test "creates quiz associated with logged in user and redirects to index on valid submission",
         %{
           conn: conn,
           user: user
         } do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      {:ok, _index_view, html} =
        view
        |> form("#quiz-form", quiz: @valid_quiz_params)
        |> render_submit()
        |> follow_redirect(conn, ~p"/quizzes")

      assert html =~ "Quiz « Quiz sur la Géographie » créé avec succès !"
      assert html =~ "Quiz sur la Géographie"

      created =
        Quizzes.list_quizzes()
        |> Enum.find(&(&1.title == "Quiz sur la Géographie"))

      assert created != nil
      assert created.user_id == user.id
    end

    test "creates a private quiz without access code", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      private_params =
        @valid_quiz_params
        |> Map.put("visibility", "private")

      {:ok, _index_view, html} =
        view
        |> form("#quiz-form", quiz: private_params)
        |> render_submit()
        |> follow_redirect(conn, ~p"/quizzes")

      assert html =~ "Quiz « Quiz sur la Géographie » créé avec succès !"
      created = Quizzes.list_quizzes() |> Enum.find(&(&1.title == "Quiz sur la Géographie"))
      assert created.visibility == "private"
    end

    test "renders errors when submitting invalid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      invalid_params =
        @valid_quiz_params
        |> Map.put("title", "")

      response =
        view
        |> form("#quiz-form", quiz: invalid_params)
        |> render_submit()

      assert response =~ "can&#39;t be blank"
    end

    test "navigates back to quizzes index via back button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/quizzes/new")

      {:ok, _view, html} =
        view
        |> element("#back-button")
        |> render_click()
        |> follow_redirect(conn, ~p"/quizzes")

      assert html =~ "Quiz disponibles"
    end
  end

  describe "GET /quizzes/:id/edit" do
    setup :register_and_log_in_user

    defp create_quiz_for_edit(user) do
      {:ok, quiz} =
        Quizzes.create_quiz(
          %{
            title: "Quiz Histoire",
            description: "Histoire de France",
            visibility: "public",
            questions: [
              %{
                body: "En quelle année a eu lieu la Révolution française ?",
                order: 1,
                time_limit_seconds: 30,
                answer_options: [
                  %{body: "1789", is_correct: true},
                  %{body: "1799", is_correct: false}
                ]
              }
            ]
          },
          user
        )

      quiz
    end

    test "renders edit form pre-populated with quiz data for owner", %{conn: conn, user: user} do
      quiz = create_quiz_for_edit(user)

      {:ok, view, _html} = live(conn, ~p"/quizzes/#{quiz}/edit")

      assert has_element?(view, "#quiz-form")
      assert has_element?(view, "#quiz-title[value='Quiz Histoire']")

      assert has_element?(
               view,
               "#question-0-body[value='En quelle année a eu lieu la Révolution française ?']"
             )

      assert has_element?(view, "#save-quiz-button", "Enregistrer les modifications")
    end

    test "redirects non-owner with error message", %{conn: conn} do
      other_user = user_fixture()
      quiz = create_quiz_for_edit(other_user)

      {:ok, _view, html} =
        live(conn, ~p"/quizzes/#{quiz}/edit")
        |> follow_redirect(conn, ~p"/quizzes")

      assert html =~ "Vous n&#39;êtes pas autorisé à modifier ce quiz."
    end

    test "updates quiz and redirects to show on valid submission", %{conn: conn, user: user} do
      quiz = create_quiz_for_edit(user)
      detailed = Quizzes.get_quiz_with_details!(quiz.id)
      [q] = detailed.questions
      [a1, a2] = q.answer_options

      update_params = %{
        "title" => "Quiz Histoire de France (Mis à jour)",
        "description" => "Description mise à jour",
        "visibility" => "public",
        "questions" => %{
          "0" => %{
            "id" => q.id,
            "order" => "1",
            "body" => "En quelle année a eu lieu la prise de la Bastille ?",
            "time_limit_seconds" => "45",
            "answer_options" => %{
              "0" => %{"id" => a1.id, "body" => "14 juillet 1789", "is_correct" => "true"},
              "1" => %{"id" => a2.id, "body" => "14 juillet 1799", "is_correct" => "false"}
            }
          }
        }
      }

      {:ok, view, _html} = live(conn, ~p"/quizzes/#{quiz}/edit")

      {:ok, _show_view, html} =
        view
        |> form("#quiz-form", quiz: update_params)
        |> render_submit()
        |> follow_redirect(conn, ~p"/quizzes/#{quiz}")

      assert html =~ "Quiz « Quiz Histoire de France (Mis à jour) » mis à jour avec succès !"
      assert html =~ "Quiz Histoire de France (Mis à jour)"
    end

    test "renders errors when updating with invalid data", %{conn: conn, user: user} do
      quiz = create_quiz_for_edit(user)
      {:ok, view, _html} = live(conn, ~p"/quizzes/#{quiz}/edit")

      response =
        view
        |> form("#quiz-form", quiz: %{"title" => ""})
        |> render_submit()

      assert response =~ "can&#39;t be blank"
    end

    test "navigates back to show page on cancel", %{conn: conn, user: user} do
      quiz = create_quiz_for_edit(user)
      {:ok, view, _html} = live(conn, ~p"/quizzes/#{quiz}/edit")

      {:ok, _show_view, html} =
        view
        |> element("#back-button")
        |> render_click()
        |> follow_redirect(conn, ~p"/quizzes/#{quiz}")

      assert html =~ quiz.title
    end
  end
end
