defmodule QuizirWeb.GameLive.JoinTest do
  use QuizirWeb.ConnCase

  alias Quizir.Games
  alias Quizir.Quizzes

  defp create_active_game(opts \\ []) do
    {:ok, quiz} =
      Quizzes.create_quiz(%{
        title: "Quiz Multijoueur",
        visibility: Keyword.get(opts, :visibility, "public"),
        access_code: Keyword.get(opts, :access_code, nil),
        questions: [
          %{
            body: "Question 1",
            order: 1,
            time_limit_seconds: 20,
            answer_options: [
              %{body: "Choix A", is_correct: true},
              %{body: "Choix B", is_correct: false}
            ]
          }
        ]
      })

    {:ok, game} = Games.create_game(quiz)
    game
  end

  describe "GET /join" do
    test "renders join form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/join")

      assert has_element?(view, "#join-game-form")
      assert has_element?(view, "#join-pin-input")
      assert has_element?(view, "#join-nickname-input")
      assert has_element?(view, "#join-access-code-input")
      assert has_element?(view, "#submit-join-btn")
    end

    test "pre-fills PIN when provided in params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/join?pin=XYZ123")

      assert has_element?(view, "#join-pin-input[value='XYZ123']")
    end

    test "validates required fields and unknown game", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/join")

      # Unknown game
      view
      |> form("#join-game-form", %{"pin" => "FAKEXY", "nickname" => "Bob"})
      |> render_submit()

      assert has_element?(view, "#join-error-alert", "Ce salon de jeu n'existe pas")
    end

    test "rejects incorrect access code for private quiz", %{conn: conn} do
      game = create_active_game(visibility: "private", access_code: "SECRET42")

      {:ok, view, _html} = live(conn, ~p"/join")

      view
      |> form("#join-game-form", %{
        "pin" => game.code,
        "nickname" => "Bob",
        "access_code" => "WRONG"
      })
      |> render_submit()

      assert has_element?(view, "#join-error-alert", "Code d'accès incorrect")
    end

    test "successfully joins game and redirects to /games/:code", %{conn: conn} do
      game = create_active_game()

      {:ok, view, _html} = live(conn, ~p"/join")

      {:ok, play_live, _html} =
        view
        |> form("#join-game-form", %{
          "pin" => game.code,
          "nickname" => "Alice",
          "access_code" => ""
        })
        |> render_submit()
        |> follow_redirect(conn)

      assert has_element?(play_live, "#lobby-screen")
      assert has_element?(play_live, "#player-status-badge", "Alice")
    end
  end
end
