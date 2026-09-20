defmodule Quizir.Games.SessionTest do
  use ExUnit.Case, async: true

  alias Quizir.Games.Session
  alias Quizir.Quizzes.{Quiz, Question, AnswerOption}

  defp sample_quiz(opts \\ []) do
    %Quiz{
      id: 1,
      title: "Quiz Test",
      visibility: Keyword.get(opts, :visibility, "public"),
      questions: [
        %Question{
          id: 10,
          order: 1,
          body: "Question 1",
          time_limit_seconds: 20,
          answer_options: [
            %AnswerOption{id: 101, body: "Option A (correct)", is_correct: true},
            %AnswerOption{id: 102, body: "Option B (false)", is_correct: false}
          ]
        },
        %Question{
          id: 20,
          order: 2,
          body: "Question 2",
          time_limit_seconds: 15,
          answer_options: [
            %AnswerOption{id: 201, body: "Option 2A (correct)", is_correct: true},
            %AnswerOption{id: 202, body: "Option 2B (false)", is_correct: false}
          ]
        }
      ]
    }
  end

  defp start_session(quiz \\ sample_quiz(), extra_opts \\ []) do
    code = "TST" <> (:crypto.strong_rand_bytes(3) |> Base.encode16())
    host_token = "host_secret_123"

    opts =
      [
        code: code,
        host_token: host_token,
        quiz: quiz,
        timer_interval: 10_000
      ] ++ extra_opts

    pid = start_supervised!({Session, opts})
    %{pid: pid, code: code, host_token: host_token, quiz: quiz}
  end

  describe "Session lifecycle" do
    test "initializes in :lobby status" do
      %{pid: pid, code: code} = start_session()
      state = Session.get_state(pid)

      assert state.status == :lobby
      assert state.code == code
      assert state.players == %{}
      assert length(state.questions) == 2
    end

    test "allows players to join and leave in lobby" do
      %{pid: pid} = start_session()

      assert {:ok, player1} = Session.join_player(pid, "Alice")
      assert player1.name == "Alice"
      assert player1.score == 0

      assert {:ok, player2} = Session.join_player(pid, "Bob")
      state = Session.get_state(pid)
      assert map_size(state.players) == 2

      # Player leaves
      assert :ok = Session.leave_player(pid, player1.id)
      state_after = Session.get_state(pid)
      assert map_size(state_after.players) == 1
      assert Map.has_key?(state_after.players, player2.id)
    end

    test "rejects empty player name" do
      %{pid: pid} = start_session()
      assert {:error, :invalid_name} = Session.join_player(pid, "   ")
    end

    test "allows joining session even if quiz is private" do
      quiz = sample_quiz(visibility: "private")
      %{pid: pid} = start_session(quiz)

      assert {:ok, player} = Session.join_player(pid, "Alice")
      assert player.name == "Alice"
    end

    test "records session visibility (public or private)" do
      quiz = sample_quiz()
      code_pub = "PUB123"
      code_priv = "PRV456"

      pid_pub =
        start_supervised!(%{
          id: :session_pub,
          start:
            {Session, :start_link,
             [[code: code_pub, host_token: "h1", quiz: quiz, visibility: "public"]]}
        })

      pid_priv =
        start_supervised!(%{
          id: :session_priv,
          start:
            {Session, :start_link,
             [[code: code_priv, host_token: "h2", quiz: quiz, visibility: "private"]]}
        })

      assert Session.get_state(pid_pub).visibility == "public"
      assert Session.get_state(pid_priv).visibility == "private"
    end

    test "starts game with valid host token" do
      %{pid: pid, host_token: host_token} = start_session()
      {:ok, _player} = Session.join_player(pid, "Alice")

      assert {:error, :unauthorized} = Session.start_game(pid, "bad_token")

      assert :ok = Session.start_game(pid, host_token)
      state = Session.get_state(pid)
      assert state.status == :question
      assert state.current_question_index == 0
      assert state.time_remaining == 20
    end

    test "handles answer submissions, scoring, and auto-finish on all answered" do
      %{pid: pid, host_token: host_token} = start_session()
      {:ok, alice} = Session.join_player(pid, "Alice")
      {:ok, bob} = Session.join_player(pid, "Bob")

      :ok = Session.start_game(pid, host_token)

      # Alice answers correctly
      assert {:ok, ans_alice} = Session.submit_answer(pid, alice.id, 101)
      assert ans_alice.is_correct == true
      assert ans_alice.points > 500

      # Bob answers incorrectly
      assert {:ok, ans_bob} = Session.submit_answer(pid, bob.id, 102)
      assert ans_bob.is_correct == false
      assert ans_bob.points == 0

      # All players answered -> automatically transitioned to :reveal!
      state = Session.get_state(pid)
      assert state.status == :reveal

      # Synchronize and check next_step to leaderboard
      assert :ok = Session.next_step(pid, host_token)
      state_lead = Session.get_state(pid)
      assert state_lead.status == :leaderboard

      # Next question
      assert :ok = Session.next_step(pid, host_token)
      state_q2 = Session.get_state(pid)
      assert state_q2.status == :question
      assert state_q2.current_question_index == 1
      assert state_q2.time_remaining == 15
    end

    test "transitions to finished on last question completion" do
      %{pid: pid, host_token: host_token} = start_session()
      {:ok, alice} = Session.join_player(pid, "Alice")
      :ok = Session.start_game(pid, host_token)

      # Q1 answer
      {:ok, _} = Session.submit_answer(pid, alice.id, 101)
      # -> leaderboard
      :ok = Session.next_step(pid, host_token)
      # -> Q2
      :ok = Session.next_step(pid, host_token)

      # Q2 answer
      {:ok, _} = Session.submit_answer(pid, alice.id, 201)
      # -> leaderboard
      :ok = Session.next_step(pid, host_token)
      # -> finished!
      :ok = Session.next_step(pid, host_token)

      state_fin = Session.get_state(pid)
      assert state_fin.status == :finished
    end
  end
end
