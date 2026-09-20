defmodule QuizirWeb.GameLive.IndexTest do
  use QuizirWeb.ConnCase

  alias Quizir.Games
  alias Quizir.Quizzes

  defp create_active_game(opts \\ []) do
    {:ok, quiz} =
      Quizzes.create_quiz(%{
        title: Keyword.get(opts, :title, "Quiz Public Test"),
        visibility: Keyword.get(opts, :quiz_visibility, "public"),
        access_code: Keyword.get(opts, :access_code, nil),
        questions: [
          %{
            body: "Question 1",
            order: 1,
            time_limit_seconds: 20,
            answer_options: [
              %{body: "Option A", is_correct: true},
              %{body: "Option B", is_correct: false}
            ]
          }
        ]
      })

    visibility = Keyword.get(opts, :visibility, "public")
    {:ok, game} = Games.create_game(quiz, visibility: visibility)
    game
  end

  describe "GET /games (Parties en cours)" do
    test "renders empty state when no public games are active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/games")

      assert has_element?(view, "#empty-games-state")
      assert has_element?(view, "#join-private-btn")
      assert has_element?(view, "#launch-own-game-btn")
    end

    test "renders active public games and ignores private games", %{conn: conn} do
      pub_game = create_active_game(title: "Partie Publique 1", visibility: "public")
      priv_game = create_active_game(title: "Partie Secrète", visibility: "private")

      {:ok, view, _html} = live(conn, ~p"/games")

      assert has_element?(view, "#games-#{pub_game.code}")
      assert has_element?(view, "#join-game-btn-#{pub_game.code}")
      refute has_element?(view, "#games-#{priv_game.code}")
      refute has_element?(view, "#join-game-btn-#{priv_game.code}")
    end

    test "guest user clicks join, opens modal, enters nickname and joins", %{conn: conn} do
      game = create_active_game(title: "Quiz Multi", visibility: "public")

      {:ok, view, _html} = live(conn, ~p"/games")

      # Click join on the game card
      view
      |> element("#join-game-btn-#{game.code}")
      |> render_click()

      # Modal is now open
      assert has_element?(view, "#guest-join-modal")
      assert has_element?(view, "#guest-nickname-input")

      # Submitting with empty nickname shows error
      view
      |> form("#guest-join-form", %{"code" => game.code, "nickname" => ""})
      |> render_submit()

      assert has_element?(view, "#guest-join-error", "Veuillez entrer un pseudo.")

      # Submitting valid nickname navigates to the game lobby
      {:ok, play_live, _html} =
        view
        |> form("#guest-join-form", %{"code" => game.code, "nickname" => "BobL'Eponge"})
        |> render_submit()
        |> follow_redirect(conn)

      assert has_element?(play_live, "#lobby-screen")
      assert has_element?(play_live, "#player-status-badge", "BobL'Eponge")
    end

    test "guest user can close modal", %{conn: conn} do
      game = create_active_game()

      {:ok, view, _html} = live(conn, ~p"/games")

      view
      |> element("#join-game-btn-#{game.code}")
      |> render_click()

      assert has_element?(view, "#guest-join-modal")

      view
      |> element("#close-guest-modal-btn")
      |> render_click()

      refute has_element?(view, "#guest-join-modal")
    end

    test "handles :refresh_games message to update the stream", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/games")

      new_game = create_active_game(title: "Partie Spontanée", visibility: "public")

      send(view.pid, :refresh_games)

      assert has_element?(view, "#games-#{new_game.code}")
    end
  end

  describe "GET /games (authenticated user)" do
    setup :register_and_log_in_user

    test "joins public game directly in 1 click without PIN or modal", %{conn: conn, user: user} do
      game = create_active_game(title: "Partie Instantanée", visibility: "public")

      {:ok, view, _html} = live(conn, ~p"/games")

      {:ok, play_live, _html} =
        view
        |> element("#join-game-btn-#{game.code}")
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(play_live, "#lobby-screen")
      assert has_element?(play_live, "#player-status-badge", user.username)
    end
  end
end
