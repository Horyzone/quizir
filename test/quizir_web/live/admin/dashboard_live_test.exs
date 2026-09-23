defmodule QuizirWeb.Admin.DashboardLiveTest do
  use QuizirWeb.ConnCase, async: false

  import Quizir.AccountsFixtures
  import Quizir.QuizzesFixtures
  alias Quizir.Accounts
  alias Quizir.Games
  alias Quizir.Quizzes

  setup do
    admin = admin_user_fixture(%{username: "superadmin"})
    player = user_fixture(%{username: "regular_player"})
    quiz = quiz_fixture(%{title: "Quiz Test Admin", visibility: "public", user: player})

    %{admin: admin, player: player, quiz: quiz}
  end

  describe "Dashboard Access & Security" do
    test "redirects unauthenticated users to /admin/log_in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin/log_in"}}} = live(conn, ~p"/admin")
    end

    test "redirects authenticated players without admin role to /admin/log_in", %{
      conn: conn,
      player: player
    } do
      conn = log_in_user(conn, player)
      assert {:error, {:redirect, %{to: "/admin/log_in"}}} = live(conn, ~p"/admin")
    end

    test "mounts dashboard successfully with stats view when authenticated as admin", %{
      conn: conn,
      admin: admin
    } do
      conn = log_in_admin(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin")

      assert has_element?(view, "#admin-dashboard-title")
      assert has_element?(view, "#tab-stats-btn")
      assert has_element?(view, "#tab-users-btn")
      assert has_element?(view, "#tab-quizzes-btn")
      assert has_element?(view, "#tab-games-btn")
      assert has_element?(view, "#admin-stats-view")
    end

    test "navbar on admin interface does not render player navigation buttons (Explorer, Parties, Mes quiz, Rejoindre)",
         %{
           conn: conn,
           admin: admin
         } do
      conn = log_in_admin(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Navbar must not have player navigation buttons
      refute has_element?(view, "header a[href='/quizzes']", "Explorer")
      refute has_element?(view, "#nav-live-games-btn")
      refute has_element?(view, "#nav-my-quizzes-btn")
      refute has_element?(view, "header a[href='/join']")

      # Navbar must have back to site link, admin badge, and admin menu
      assert has_element?(view, "#nav-back-to-site-btn")
      assert has_element?(view, "#admin-menu-btn")
      assert has_element?(view, "#header-admin-badge")
      assert has_element?(view, "#nav-admin-settings-btn")
    end
  end

  describe "Detailed Statistics View" do
    test "displays all metrics cards, presence stats, and completed games table", %{
      conn: conn,
      admin: admin,
      quiz: quiz
    } do
      # Create a completed game record
      {:ok, _record} =
        Games.create_game_record(%{
          code: "WIN999",
          quiz_id: quiz.id,
          quiz_title: quiz.title,
          visibility: "public",
          players_count: 5,
          winner_name: "Champion",
          winner_score: 450,
          status: "completed",
          finished_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      conn = log_in_admin(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin")

      assert has_element?(view, "#admin-stats-view")
      assert has_element?(view, "#admin-kpi-cards")
      assert has_element?(view, "#stat-connected-total")
      assert has_element?(view, "#stat-active-games")
      assert has_element?(view, "#stat-completed-games")
      assert has_element?(view, "#stat-quiz-total")
      assert has_element?(view, "#stat-user-total")
      assert has_element?(view, "#admin-completed-games-table")

      # Click refresh stats
      view
      |> element("#stats-refresh-btn")
      |> render_click()

      assert has_element?(view, "#admin-stats-view")
    end

    test "real-time updates: dashboard updates automatically on PubSub broadcast", %{
      conn: conn,
      admin: admin,
      quiz: quiz
    } do
      conn = log_in_admin(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin")

      assert has_element?(view, "#admin-live-badge")

      # Create a new completed game and broadcast admin_game_event
      {:ok, _record} =
        Games.create_game_record(%{
          code: "REALTIME01",
          quiz_id: quiz.id,
          quiz_title: "Quiz Realtime",
          visibility: "public",
          players_count: 8,
          winner_name: "LiveWinner",
          winner_score: 999,
          status: "completed",
          finished_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      Phoenix.PubSub.broadcast(
        Quizir.PubSub,
        "admin:dashboard",
        {:admin_game_event, :game_finished, "REALTIME01"}
      )

      # Without clicking refresh, LiveView receives broadcast and renders new row
      assert render(view) =~ "REALTIME01"
      assert render(view) =~ "LiveWinner"
    end
  end

  describe "Tab Switching" do
    test "can switch between Stats, Users, Quizzes, and Games tabs", %{
      conn: conn,
      admin: admin,
      quiz: quiz
    } do
      conn = log_in_admin(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin")

      # Stats tab is active by default
      assert has_element?(view, "#admin-stats-view")
      refute has_element?(view, "#admin-users-table")
      refute has_element?(view, "#admin-quizzes-table")
      refute has_element?(view, "#admin-games-table")

      # Switch to Users tab
      view
      |> element("#tab-users-btn")
      |> render_click()

      assert has_element?(view, "#admin-users-table")
      refute has_element?(view, "#admin-stats-view")

      # Switch to Quizzes tab
      view
      |> element("#tab-quizzes-btn")
      |> render_click()

      assert has_element?(view, "#admin-quizzes-table")
      assert has_element?(view, "#quiz-row-#{quiz.id}")
      refute has_element?(view, "#admin-users-table")

      # Switch to Games tab
      view
      |> element("#tab-games-btn")
      |> render_click()

      assert has_element?(view, "#admin-games-table")
      refute has_element?(view, "#admin-quizzes-table")

      # Switch back to Stats tab
      view
      |> element("#tab-stats-btn")
      |> render_click()

      assert has_element?(view, "#admin-stats-view")
    end
  end

  describe "Users Management" do
    test "can search users by username", %{
      conn: conn,
      admin: admin,
      player: player
    } do
      conn = log_in_admin(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin?tab=users")

      assert has_element?(view, "#user-row-#{player.id}")
      assert has_element?(view, "#user-row-#{admin.id}")

      # Search for regular_player
      view
      |> element("#admin-search-users-form")
      |> render_change(%{"search" => "regular_player"})

      assert has_element?(view, "#user-row-#{player.id}")
      refute has_element?(view, "#user-row-#{admin.id}")

      # Search non-matching
      view
      |> element("#admin-search-users-form")
      |> render_change(%{"search" => "non_existent_xyz"})

      refute has_element?(view, "#user-row-#{player.id}")
      refute has_element?(view, "#user-row-#{admin.id}")
    end

    test "can promote a user to admin and demote back", %{
      conn: conn,
      admin: admin,
      player: player
    } do
      conn = log_in_admin(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin?tab=users")

      refute player.admin

      # Promote player to admin
      view
      |> element("#toggle-admin-btn-#{player.id}")
      |> render_click()

      updated_player = Accounts.get_user!(player.id)
      assert updated_player.admin

      # Demote back
      view
      |> element("#toggle-admin-btn-#{player.id}")
      |> render_click()

      demoted_player = Accounts.get_user!(player.id)
      refute demoted_player.admin
    end

    test "cannot demote or delete oneself", %{
      conn: conn,
      admin: admin
    } do
      conn = log_in_admin(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin?tab=users")

      # Action buttons should not exist for oneself in the UI
      refute has_element?(view, "#toggle-admin-btn-#{admin.id}")
      refute has_element?(view, "#delete-user-btn-#{admin.id}")

      # If an event is forged, the backend safeguard blocks it
      render_click(view, "toggle_admin", %{"user_id" => "#{admin.id}"})
      assert Accounts.get_user!(admin.id).admin

      render_click(view, "delete_user", %{"user_id" => "#{admin.id}"})
      assert Accounts.get_user!(admin.id)
    end

    test "can delete another user account", %{
      conn: conn,
      admin: admin,
      player: player
    } do
      conn = log_in_admin(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin?tab=users")

      assert has_element?(view, "#delete-user-btn-#{player.id}")

      view
      |> element("#delete-user-btn-#{player.id}")
      |> render_click()

      refute Accounts.get_user(player.id)
      refute has_element?(view, "#user-row-#{player.id}")
    end
  end

  describe "Quizzes Management" do
    test "can search and delete a quiz", %{
      conn: conn,
      admin: admin,
      quiz: quiz
    } do
      other_quiz = quiz_fixture(%{title: "Autre Quiz Special", visibility: "public"})

      conn = log_in_admin(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin?tab=quizzes")

      assert has_element?(view, "#quiz-row-#{quiz.id}")
      assert has_element?(view, "#quiz-row-#{other_quiz.id}")

      # Search
      view
      |> element("#admin-search-quizzes-form")
      |> render_change(%{"search" => "Special"})

      assert has_element?(view, "#quiz-row-#{other_quiz.id}")
      refute has_element?(view, "#quiz-row-#{quiz.id}")

      # Clear search
      view
      |> element("#admin-search-quizzes-form")
      |> render_change(%{"search" => ""})

      # Delete quiz
      view
      |> element("#delete-quiz-btn-#{quiz.id}")
      |> render_click()

      assert_raise Ecto.NoResultsError, fn ->
        Quizzes.get_quiz!(quiz.id)
      end

      refute has_element?(view, "#quiz-row-#{quiz.id}")
    end
  end

  describe "Games Management" do
    test "lists active multiplayer games and can terminate them", %{
      conn: conn,
      admin: admin,
      quiz: quiz
    } do
      {:ok, %{code: code}} = Games.create_game(quiz)
      assert Games.game_exists?(code)

      conn = log_in_admin(conn, admin)
      {:ok, view, _html} = live(conn, ~p"/admin?tab=games")

      assert has_element?(view, "#game-row-#{code}")
      assert has_element?(view, "#stop-game-btn-#{code}")

      # Terminate game
      view
      |> element("#stop-game-btn-#{code}")
      |> render_click()

      refute Games.game_exists?(code)
      refute has_element?(view, "#game-row-#{code}")
    end
  end
end
