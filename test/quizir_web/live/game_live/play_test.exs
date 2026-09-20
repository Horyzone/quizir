defmodule QuizirWeb.GameLive.PlayTest do
  use QuizirWeb.ConnCase

  alias Quizir.Games
  alias Quizir.Quizzes

  defp create_game_with_questions do
    {:ok, quiz} =
      Quizzes.create_quiz(%{
        title: "Quiz Live Battle",
        visibility: "public",
        questions: [
          %{
            body: "Quelle planète est la plus proche du Soleil ?",
            order: 1,
            time_limit_seconds: 20,
            answer_options: [
              %{body: "Mercure", is_correct: true},
              %{body: "Vénus", is_correct: false}
            ]
          }
        ]
      })

    {:ok, game} = Games.create_game(quiz)
    game
  end

  describe "GET /games/:code" do
    test "redirects to quizzes when game does not exist", %{conn: conn} do
      {:ok, _view, html} =
        live(conn, ~p"/games/UNKNOWN")
        |> follow_redirect(conn, ~p"/quizzes")

      assert html =~ "Quiz disponibles"
    end

    test "renders host lobby when mounted with host_token", %{conn: conn} do
      game = create_game_with_questions()

      {:ok, view, _html} =
        live(conn, ~p"/games/#{game.code}?host_token=#{game.host_token}")

      assert has_element?(view, "#host-badge")
      assert has_element?(view, "#lobby-pin", game.code)
      assert has_element?(view, "#host-start-game-btn")
    end

    test "renders inline join form for visitor without player or host role", %{conn: conn} do
      game = create_game_with_questions()

      {:ok, view, _html} = live(conn, ~p"/games/#{game.code}")

      assert has_element?(view, "#inline-join-card")
      assert has_element?(view, "#inline-player-name")

      # Submits inline join
      view
      |> form("#inline-join-form", %{"name" => "Visiteur"})
      |> render_submit()

      assert has_element?(view, "#player-status-badge", "Visiteur")
      assert has_element?(view, "#lobby-screen")
    end

    test "full game loop: lobby -> question -> answer -> reveal -> leaderboard -> finished", %{
      conn: conn
    } do
      game = create_game_with_questions()

      # 1. Host connects
      {:ok, host_view, _} =
        live(conn, ~p"/games/#{game.code}?host_token=#{game.host_token}")

      # 2. Player connects and joins
      {:ok, player} = Games.join_game(game.code, "Joueur1")

      {:ok, player_view, _} =
        live(conn, ~p"/games/#{game.code}?player_id=#{player.id}&name=Joueur1")

      assert has_element?(host_view, "#player-badge-#{player.id}", "Joueur1")
      assert has_element?(player_view, "#player-waiting-notice")

      # 3. Host starts the game
      host_view
      |> element("#host-start-game-btn")
      |> render_click()

      # Both views show question screen
      assert has_element?(host_view, "#question-screen")
      assert has_element?(player_view, "#question-screen")
      assert has_element?(player_view, "#question-text", "plus proche du Soleil")

      # 4. Player answers
      {:ok, state} = Games.get_game_state(game.code)
      [q1] = state.questions
      correct_opt = Enum.find(q1.answer_options, & &1.is_correct)

      player_view
      |> element("#answer-option-btn-#{correct_opt.id}")
      |> render_click()

      # Since all active players answered, game automatically transitions to reveal
      assert has_element?(player_view, "#reveal-screen")
      assert has_element?(player_view, "#player-correct-banner")
      assert has_element?(host_view, "#reveal-screen")

      # 5. Host advances to leaderboard
      host_view
      |> element("#host-show-leaderboard-btn")
      |> render_click()

      assert has_element?(host_view, "#leaderboard-screen")
      assert has_element?(player_view, "#leaderboard-screen")
      assert has_element?(player_view, "#leaderboard-list", "Joueur1")

      # 6. Host advances past final question -> finished!
      host_view
      |> element("#host-next-question-btn")
      |> render_click()

      assert has_element?(host_view, "#finished-screen")
      assert has_element?(player_view, "#finished-screen")
      assert has_element?(player_view, "#podium-1st", "Joueur1")
    end

    test "host can participate in their own game as a player and answer questions", %{
      conn: conn
    } do
      game = create_game_with_questions()

      # 1. Host connects
      {:ok, host_view, _} =
        live(conn, ~p"/games/#{game.code}?host_token=#{game.host_token}")

      assert has_element?(host_view, "#host-badge")
      assert has_element?(host_view, "#host-join-card")

      # 2. Host joins the game as a player
      host_view
      |> form("#host-join-card form", %{"nickname" => "MoiLeHost"})
      |> render_submit()

      assert has_element?(host_view, "#player-status-badge", "MoiLeHost")
      assert has_element?(host_view, "#host-playing-badge", "MoiLeHost")

      # 3. Host starts the game
      host_view
      |> element("#host-start-game-btn")
      |> render_click()

      assert has_element?(host_view, "#question-screen")

      # 4. Host can answer the question directly
      {:ok, state} = Games.get_game_state(game.code)
      [q1] = state.questions
      correct_opt = Enum.find(q1.answer_options, & &1.is_correct)

      host_view
      |> element("#answer-option-btn-#{correct_opt.id}")
      |> render_click()

      # Reveal screen shows correct answer banner for the host
      assert has_element?(host_view, "#reveal-screen")
      assert has_element?(host_view, "#player-correct-banner")

      # 5. Host advances to leaderboard and sees themselves on the leaderboard
      host_view
      |> element("#host-show-leaderboard-btn")
      |> render_click()

      assert has_element?(host_view, "#leaderboard-screen")
      assert has_element?(host_view, "#leaderboard-list", "MoiLeHost")

      # 6. Host advances to finished podium
      host_view
      |> element("#host-next-question-btn")
      |> render_click()

      assert has_element?(host_view, "#finished-screen")
      assert has_element?(host_view, "#podium-1st", "MoiLeHost")
    end
  end
end
