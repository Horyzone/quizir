defmodule QuizirWeb.HomeLiveTest do
  use QuizirWeb.ConnCase

  alias Quizir.Games
  alias Quizir.Quizzes
  import Quizir.QuizzesFixtures

  defp create_game_fixture do
    quiz = quiz_fixture(%{title: "Quiz Astro", visibility: "public"})
    question = question_fixture(%{body: "Capitale de Mars ?", order: 1, time_limit_seconds: 20})

    # Associate question with quiz in DB
    Ecto.Changeset.change(question, quiz_id: quiz.id) |> Quizir.Repo.update!()

    _opt = answer_option_fixture(%{body: "Phobos", is_correct: true, question_id: question.id})

    detailed_quiz = Quizzes.get_quiz_with_details!(quiz.id)
    {:ok, game} = Games.create_game(detailed_quiz)
    game
  end

  describe "GET / (HomeLive) unauthenticated" do
    test "renders landing page with hero, cta, simulation, and steps", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      # Static page assertions
      assert html =~ "Défiez vos amis avec des"
      assert html =~ "quiz en direct"

      # Buttons for unauthenticated user
      assert has_element?(view, "#hero-join-game-btn")
      assert has_element?(view, "#hero-register-btn")

      # Quick join card
      assert has_element?(view, "#quick-join-form")
      assert has_element?(view, "#quick-join-pin")
      assert has_element?(view, "#quick-join-nickname")
      assert has_element?(view, "#quick-join-submit-btn")

      # Interactive simulation preview
      assert html =~ "En quelle année le premier homme a-t-il marché sur la Lune ?"
      assert html =~ "Apollo 11"

      # How it works
      assert html =~ "Comment lancer votre partie en 3 étapes"
      assert html =~ "Créez votre Quiz"
      assert html =~ "Partagez le code PIN"
      assert html =~ "Jouez &amp; gagnez"

      # Features
      assert html =~ "Pourquoi choisir Quizir ?"
      assert html =~ "Temps réel"
      assert html =~ "Hôte participant"
    end

    test "navbar on public site renders player navigation buttons (Explorer, Parties, Rejoindre)",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "header a[href='/quizzes']", "Explorer")
      assert has_element?(view, "#nav-live-games-btn")
      assert has_element?(view, "header a[href='/join']")
    end

    test "quick join validation on empty fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#quick-join-form", %{"quick_join" => %{"pin" => "", "nickname" => ""}})
      |> render_submit()

      assert has_element?(view, "#quick-join-error", "Veuillez entrer le code PIN du salon.")
    end

    test "quick join with invalid or non-existent PIN shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#quick-join-form", %{"quick_join" => %{"pin" => "999999", "nickname" => "Bob"}})
      |> render_submit()

      assert has_element?(view, "#quick-join-error", "Ce salon de jeu n'existe pas")
    end

    test "quick join with valid existing game redirects to game room", %{conn: conn} do
      game = create_game_fixture()
      {:ok, view, _html} = live(conn, ~p"/")

      {:ok, game_view, _html} =
        view
        |> form("#quick-join-form", %{
          "quick_join" => %{"pin" => game.code, "nickname" => "Alice"}
        })
        |> render_submit()
        |> follow_redirect(conn)

      assert has_element?(game_view, "#player-status-badge", "Alice")
    end

    test "renders featured public quizzes if they exist", %{conn: conn} do
      quiz = quiz_fixture(%{title: "Quiz Culture Populaire", visibility: "public"})

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#featured-quiz-#{quiz.id}")
      assert has_element?(view, "#featured-quiz-#{quiz.id}", "Quiz Culture Populaire")
    end

    test "renders featured public quiz card image when present", %{conn: conn} do
      quiz =
        quiz_fixture(%{
          title: "Quiz Cinéma Populaire",
          visibility: "public",
          image_url: "https://example.com/featured.jpg"
        })

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(
               view,
               "#featured-quiz-#{quiz.id} img[src='https://example.com/featured.jpg']"
             )
    end
  end

  describe "GET / (HomeLive) authenticated" do
    setup :register_and_log_in_user

    test "renders authenticated hero CTAs and pre-fills nickname in quick join", %{
      conn: conn,
      user: user
    } do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#hero-create-quiz-btn")
      assert has_element?(view, "#hero-explore-quizzes-btn")
      refute has_element?(view, "#hero-register-btn")

      # Quick join nickname input is pre-filled with the user's username
      assert has_element?(view, "#quick-join-nickname[value='#{user.username}']")
    end
  end
end
