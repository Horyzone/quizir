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

    test "displays quiz image in lobby and question image during question phase", %{conn: conn} do
      {:ok, quiz} =
        Quizzes.create_quiz(%{
          title: "Quiz avec Visuels",
          visibility: "public",
          image_url: "https://example.com/quiz_lobby.jpg",
          questions: [
            %{
              body: "Comment s'appelle l'acteur sur cette photo ?",
              order: 1,
              time_limit_seconds: 20,
              image_url: "https://example.com/actor_photo.png",
              answer_options: [
                %{body: "Acteur A", is_correct: true},
                %{body: "Acteur B", is_correct: false}
              ]
            }
          ]
        })

      {:ok, game} = Games.create_game(quiz)

      # In lobby
      {:ok, view, _html} = live(conn, ~p"/games/#{game.code}?host_token=#{game.host_token}")
      assert has_element?(view, "#lobby-screen img[src='https://example.com/quiz_lobby.jpg']")

      # Start game -> question screen
      view |> element("#host-start-game-btn") |> render_click()
      assert has_element?(view, "#question-screen")
      assert has_element?(view, "#question-image[src='https://example.com/actor_photo.png']")
    end

    test "renders game audio controller hook and audio toolbar with background music options", %{
      conn: conn
    } do
      game = create_game_with_questions()

      {:ok, view, _html} =
        live(conn, ~p"/games/#{game.code}?host_token=#{game.host_token}")

      assert has_element?(view, "#game-audio-controller")
      assert has_element?(view, "#game-audio-toolbar")
      assert has_element?(view, "#audio-sfx-toggle")
      assert has_element?(view, "#audio-music-toggle")
      assert has_element?(view, "#audio-track-toggle")
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

    test "re-submitting inline join does not create duplicate player", %{conn: conn} do
      game = create_game_with_questions()

      {:ok, view, _html} = live(conn, ~p"/games/#{game.code}")

      # First join
      view
      |> form("#inline-join-form", %{"name" => "SuperJoueur"})
      |> render_submit()

      assert has_element?(view, "#player-status-badge", "SuperJoueur")

      # Try to join again with same name via Games context
      {:ok, player2} = Games.join_game(game.code, "SuperJoueur")
      {:ok, state} = Games.get_game_state(game.code)

      assert map_size(state.players) == 1
      assert player2.name == "SuperJoueur"
    end

    test "host joining does not generate multiple player slots", %{conn: conn} do
      game = create_game_with_questions()

      {:ok, host_view, _} = live(conn, ~p"/games/#{game.code}?host_token=#{game.host_token}")

      host_view
      |> form("#host-join-card form", %{"nickname" => "CaptainHost"})
      |> render_submit()

      assert has_element?(host_view, "#player-status-badge", "CaptainHost")
      refute has_element?(host_view, "#host-join-card")

      # Another join attempt with same name
      {:ok, re_player} = Games.join_game(game.code, "CaptainHost")
      {:ok, state} = Games.get_game_state(game.code)

      assert map_size(state.players) == 1
      assert re_player.name == "CaptainHost"
    end

    test "when a player leaves the page, they are automatically expelled", %{conn: conn} do
      game = create_game_with_questions()

      {:ok, host_view, _} = live(conn, ~p"/games/#{game.code}?host_token=#{game.host_token}")

      {:ok, player} = Games.join_game(game.code, "JoueurEphemere")

      {:ok, player_view, _} =
        live(conn, ~p"/games/#{game.code}?player_id=#{player.id}&name=JoueurEphemere")

      assert has_element?(host_view, "#player-badge-#{player.id}")
      {:ok, state} = Games.get_game_state(game.code)
      assert map_size(state.players) == 1

      # Player leaves the page (LiveView process stopped)
      GenServer.stop(player_view.pid)

      _ = :sys.get_state(Games.Session.via_tuple(game.code))

      {:ok, state_after} = Games.get_game_state(game.code)
      assert map_size(state_after.players) == 0
      refute has_element?(host_view, "#player-badge-#{player.id}")
    end

    test "when host leaves before game start and no players remain, session terminates", %{
      conn: conn
    } do
      game = create_game_with_questions()

      {:ok, host_view, _} = live(conn, ~p"/games/#{game.code}?host_token=#{game.host_token}")

      assert Games.game_exists?(game.code)

      # Host leaves the page
      [{session_pid, _}] = Registry.lookup(Quizir.Games.SessionRegistry, game.code)
      ref = Process.monitor(session_pid)
      GenServer.stop(host_view.pid)

      assert_receive {:DOWN, ^ref, :process, ^session_pid, :normal}
      _ = :sys.get_state(Quizir.Games.SessionRegistry)

      refute Games.game_exists?(game.code)
      assert {:error, :not_found} = Games.get_game_state(game.code)
    end

    test "leave lobby button navigates away and expels player", %{conn: conn} do
      game = create_game_with_questions()

      {:ok, host_view, _} = live(conn, ~p"/games/#{game.code}?host_token=#{game.host_token}")

      {:ok, player} = Games.join_game(game.code, "Partant")

      {:ok, player_view, _} =
        live(conn, ~p"/games/#{game.code}?player_id=#{player.id}&name=Partant")

      assert has_element?(player_view, "#leave-lobby-btn")

      {:ok, _games_view, html} =
        player_view
        |> element("#leave-lobby-btn")
        |> render_click()
        |> follow_redirect(conn, ~p"/games")

      assert html =~ "Parties en cours"

      _ = :sys.get_state(Games.Session.via_tuple(game.code))

      {:ok, state} = Games.get_game_state(game.code)
      assert map_size(state.players) == 0
      refute has_element?(host_view, "#player-badge-#{player.id}")
    end

    test "greys out answer buttons and displays notice for host who has not joined as a player",
         %{
           conn: conn
         } do
      game = create_game_with_questions()

      # 1. Host connects (without joining as player)
      {:ok, host_view, _} = live(conn, ~p"/games/#{game.code}?host_token=#{game.host_token}")

      # 2. Player connects and joins
      {:ok, player} = Games.join_game(game.code, "JoueurTest")

      {:ok, player_view, _} =
        live(conn, ~p"/games/#{game.code}?player_id=#{player.id}&name=JoueurTest")

      # 3. Host starts game
      host_view
      |> element("#host-start-game-btn")
      |> render_click()

      # 4. Host sees warning notice and greyed out buttons
      assert has_element?(
               host_view,
               "#host-non-player-notice",
               "Vous ne pouvez pas répondre aux questions car vous n'êtes pas un joueur"
             )

      assert has_element?(host_view, "button[id^='answer-option-btn-'][disabled]")
      assert has_element?(host_view, "button[id^='answer-option-btn-'].grayscale")

      # 5. Regular player does NOT see warning notice and has active buttons
      refute has_element?(player_view, "#host-non-player-notice")
      assert has_element?(player_view, "button[id^='answer-option-btn-']:not([disabled])")
    end
  end
end
