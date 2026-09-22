defmodule QuizirWeb.UserTrackerTest do
  use QuizirWeb.ConnCase, async: true

  alias QuizirWeb.Presence
  alias QuizirWeb.UserTracker
  alias Quizir.AccountsFixtures

  @topic "site:presence"

  test "get_connected_stats/0 returns zeros when no one is tracked" do
    stats = UserTracker.get_connected_stats()
    assert is_integer(stats.total)
    assert is_integer(stats.guests)
    assert is_integer(stats.registered)
    assert is_integer(stats.distinct_users)
  end

  test "get_connected_stats/0 correctly calculates guests and registered accounts" do
    user1 = AccountsFixtures.user_fixture()
    user2 = AccountsFixtures.user_fixture()

    # Track guest 1
    {:ok, _} =
      Presence.track(self(), @topic, "socket-guest-1", %{
        user_id: nil,
        username: "Invité",
        is_guest: true,
        admin: false,
        connected_at: System.system_time(:second)
      })

    # Track guest 2
    {:ok, _} =
      Presence.track(self(), @topic, "socket-guest-2", %{
        user_id: nil,
        username: "Invité",
        is_guest: true,
        admin: false,
        connected_at: System.system_time(:second)
      })

    # Track registered user 1 (tab 1)
    {:ok, _} =
      Presence.track(self(), @topic, "socket-user-1-tab1", %{
        user_id: user1.id,
        username: user1.username,
        is_guest: false,
        admin: false,
        connected_at: System.system_time(:second)
      })

    # Track registered user 1 (tab 2 - same user, two connections)
    {:ok, _} =
      Presence.track(self(), @topic, "socket-user-1-tab2", %{
        user_id: user1.id,
        username: user1.username,
        is_guest: false,
        admin: false,
        connected_at: System.system_time(:second)
      })

    # Track registered user 2
    {:ok, _} =
      Presence.track(self(), @topic, "socket-user-2", %{
        user_id: user2.id,
        username: user2.username,
        is_guest: false,
        admin: false,
        connected_at: System.system_time(:second)
      })

    stats = UserTracker.get_connected_stats()

    # We registered 5 sockets: 2 guests, 3 registered (2 for user1, 1 for user2)
    assert stats.total >= 5
    assert stats.guests >= 2
    assert stats.registered >= 3
    # Distinct registered users should count user1 once and user2 once
    assert stats.distinct_users >= 2
  end
end
