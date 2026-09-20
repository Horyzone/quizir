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

    test "returns :not_found for non-existent game code" do
      assert Games.game_exists?("UNKNOWN") == false
      assert Games.get_game_state("UNKNOWN") == {:error, :not_found}
      assert Games.join_game("UNKNOWN", "Alice") == {:error, :not_found}
    end
  end
end
