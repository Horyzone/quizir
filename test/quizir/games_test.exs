defmodule Quizir.GamesTest do
  use Quizir.DataCase

  alias Quizir.Games
  alias Quizir.Quizzes

  defp create_persisted_quiz do
    {:ok, quiz} =
      Quizzes.create_quiz(%{
        title: "Quiz Contexte Games",
        visibility: "public",
        questions: [
          %{
            body: "Question 1",
            order: 1,
            time_limit_seconds: 20,
            answer_options: [
              %{body: "Choix 1", is_correct: true},
              %{body: "Choix 2", is_correct: false}
            ]
          }
        ]
      })

    quiz
  end

  describe "Quizir.Games context" do
    test "create_game/2 starts a session under DynamicSupervisor and is accessible via code" do
      quiz = create_persisted_quiz()

      assert {:ok, %{code: code, host_token: host_token, pid: pid}} = Games.create_game(quiz)
      assert is_pid(pid)
      assert is_binary(code)
      assert is_binary(host_token)

      assert Games.game_exists?(code)
      assert {:ok, state} = Games.get_game_state(code)
      assert state.code == code
      assert state.status == :lobby
    end

    test "join_game/3 and submit_answer/3 through context API" do
      quiz = create_persisted_quiz()
      {:ok, %{code: code, host_token: host_token}} = Games.create_game(quiz)

      assert {:ok, player} = Games.join_game(code, "Charlie")
      assert player.name == "Charlie"

      assert :ok = Games.start_game(code, host_token)
      assert {:ok, state} = Games.get_game_state(code)
      assert state.status == :question

      option_id = hd(hd(state.questions).answer_options).id
      assert {:ok, ans} = Games.submit_answer(code, player.id, option_id)
      assert ans.is_correct == true
    end

    test "create_game/2 supports public and private visibility" do
      quiz = create_persisted_quiz()

      {:ok, %{code: pub_code, visibility: pub_vis}} =
        Games.create_game(quiz, visibility: "public")

      {:ok, %{code: priv_code, visibility: priv_vis}} =
        Games.create_game(quiz, visibility: "private")

      assert pub_vis == "public"
      assert priv_vis == "private"

      public_games = Games.list_active_public_games()
      public_codes = Enum.map(public_games, & &1.code)

      assert pub_code in public_codes
      refute priv_code in public_codes
    end

    test "returns :not_found for non-existent game code" do
      assert Games.game_exists?("UNKNOWN") == false
      assert Games.get_game_state("UNKNOWN") == {:error, :not_found}
      assert Games.join_game("UNKNOWN", "Alice") == {:error, :not_found}
    end

    test "list_all_active_games/0, count_active_games/0, terminate_game_by_admin/1" do
      quiz = create_persisted_quiz()
      {:ok, %{code: pub_code}} = Games.create_game(quiz, visibility: "public")
      {:ok, %{code: priv_code}} = Games.create_game(quiz, visibility: "private")

      assert Games.count_active_games() >= 2
      all_games = Games.list_all_active_games()
      all_codes = Enum.map(all_games, & &1.code)

      assert pub_code in all_codes
      assert priv_code in all_codes

      # Terminate game
      assert :ok = Games.terminate_game_by_admin(pub_code)
      refute Games.game_exists?(pub_code)

      # Non-existent game termination returns :not_found
      assert {:error, :not_found} = Games.terminate_game_by_admin("NONEXISTENT")
    end
  end
end
