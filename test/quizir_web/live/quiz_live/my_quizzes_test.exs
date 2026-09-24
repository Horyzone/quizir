defmodule QuizirWeb.QuizLive.MyQuizzesTest do
  use QuizirWeb.ConnCase

  import Quizir.AccountsFixtures
  import Quizir.QuizzesFixtures

  alias Quizir.Quizzes

  describe "My Quizzes page access" do
    test "redirects unauthenticated user to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, ~p"/my-quizzes")
    end

    test "renders empty state when user has no quizzes", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/my-quizzes")

      assert has_element?(view, "#empty-quizzes-state")
      assert has_element?(view, "h1", "Mes Quiz")
      assert has_element?(view, "#filter-all-btn")
      assert has_element?(view, "#filter-public-btn")
      assert has_element?(view, "#filter-private-btn")
    end
  end

  describe "List and filter user quizzes" do
    setup %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()

      my_public =
        quiz_fixture(%{
          user: user,
          title: "Mon Quiz Public",
          visibility: "public"
        })

      my_private =
        quiz_fixture(%{
          user: user,
          title: "Mon Quiz Privé",
          visibility: "private"
        })

      other_quiz =
        quiz_fixture(%{
          user: other_user,
          title: "Quiz d'un autre utilisateur",
          visibility: "public"
        })

      %{
        conn: log_in_user(conn, user),
        user: user,
        my_public: my_public,
        my_private: my_private,
        other_quiz: other_quiz
      }
    end

    test "displays only quizzes created by the current user", %{
      conn: conn,
      my_public: my_public,
      my_private: my_private,
      other_quiz: other_quiz
    } do
      {:ok, view, _html} = live(conn, ~p"/my-quizzes")

      assert has_element?(view, "#quiz-link-#{my_public.id}", my_public.title)
      assert has_element?(view, "#quiz-link-#{my_private.id}", my_private.title)
      refute has_element?(view, "#quiz-link-#{other_quiz.id}")
    end

    test "renders quiz card image when present in my quizzes", %{conn: conn, user: user} do
      quiz =
        quiz_fixture(%{
          user: user,
          title: "Mon Quiz Illustré",
          visibility: "public",
          image_url: "https://example.com/my_card_image.png"
        })

      {:ok, view, _html} = live(conn, ~p"/my-quizzes")

      assert has_element?(
               view,
               "#quizzes-#{quiz.id} img[src='https://example.com/my_card_image.png']"
             )
    end

    test "filters by public quizzes", %{
      conn: conn,
      my_public: my_public,
      my_private: my_private
    } do
      {:ok, view, _html} = live(conn, ~p"/my-quizzes")

      # Click on public filter
      view |> element("#filter-public-btn") |> render_click()

      assert has_element?(view, "#quiz-link-#{my_public.id}")
      refute has_element?(view, "#quiz-link-#{my_private.id}")
    end

    test "filters by private quizzes", %{
      conn: conn,
      my_public: my_public,
      my_private: my_private
    } do
      {:ok, view, _html} = live(conn, ~p"/my-quizzes")

      # Click on private filter
      view |> element("#filter-private-btn") |> render_click()

      assert has_element?(view, "#quiz-link-#{my_private.id}")
      refute has_element?(view, "#quiz-link-#{my_public.id}")
    end
  end

  describe "Quiz actions from My Quizzes" do
    setup %{conn: conn} do
      user = user_fixture()
      quiz = quiz_fixture(%{user: user, title: "Quiz à manipuler"})

      %{conn: log_in_user(conn, user), user: user, quiz: quiz}
    end

    test "deletes a quiz", %{conn: conn, quiz: quiz} do
      {:ok, view, _html} = live(conn, ~p"/my-quizzes")

      assert has_element?(view, "#quiz-link-#{quiz.id}")

      view |> element("#delete-quiz-#{quiz.id}-btn") |> render_click()

      refute has_element?(view, "#quiz-link-#{quiz.id}")
      assert has_element?(view, "[role=alert]", "Quiz « #{quiz.title} » supprimé avec succès.")

      assert_raise Ecto.NoResultsError, fn ->
        Quizzes.get_quiz!(quiz.id)
      end
    end

    test "duplicates a quiz", %{conn: conn, quiz: quiz} do
      {:ok, view, _html} = live(conn, ~p"/my-quizzes")

      assert has_element?(view, "#duplicate-quiz-#{quiz.id}-btn")

      {:error, {:live_redirect, %{to: redirect_path}}} =
        view |> element("#duplicate-quiz-#{quiz.id}-btn") |> render_click()

      assert redirect_path =~ ~r"/quizzes/\d+/edit"
    end

    test "launches game directly from quiz card", %{conn: conn, quiz: quiz} do
      {:ok, view, _html} = live(conn, ~p"/my-quizzes")

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

    test "shares the same live session with games routes to avoid cross-session navigation", %{
      conn: _conn
    } do
      routes = QuizirWeb.Router.__routes__()

      get_live_session = fn path ->
        route = Enum.find(routes, fn r -> r.path == path end)
        {_view, _action, _opts, %{name: name}} = route.metadata.phoenix_live_view
        name
      end

      assert get_live_session.("/my-quizzes") == :current_user
      assert get_live_session.("/games/:code") == :current_user
      assert get_live_session.("/quizzes") == :current_user
    end
  end
end
