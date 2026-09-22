defmodule QuizirWeb.UserTracker do
  @moduledoc """
  Tracks active LiveView connections (both registered users and anonymous guests)
  using Phoenix.Presence.
  """
  alias QuizirWeb.Presence

  @topic "site:presence"

  @doc """
  Tracks a connected socket in Phoenix.Presence.
  Safe to call on disconnected sockets (no-op).
  """
  def track_socket(socket, user) do
    if Phoenix.LiveView.connected?(socket) do
      key = socket.id

      meta = %{
        user_id: user && user.id,
        username: (user && user.username) || "Invité",
        is_guest: is_nil(user),
        admin: (user && user.admin) || false,
        connected_at: System.system_time(:second)
      }

      case Presence.get_by_key(@topic, key) do
        [] ->
          Presence.track(self(), @topic, key, meta)

        _ ->
          Presence.update(self(), @topic, key, meta)
      end
    end
  rescue
    _ -> :ok
  end

  @doc """
  Returns aggregated statistics on connected users:
  - total: nombre total de connexions LiveView actives
  - guests: nombre d'invités (non connectés à un compte)
  - registered: nombre de connexions d'utilisateurs inscrits
  - distinct_users: nombre de comptes distincts connectés
  """
  def get_connected_stats do
    presences = Presence.list(@topic)

    metas =
      Enum.flat_map(presences, fn {_key, %{metas: metas}} -> metas end)

    total = length(metas)
    guests = Enum.count(metas, & &1.is_guest)
    registered = total - guests

    distinct_users =
      metas
      |> Enum.map(& &1.user_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> length()

    %{
      total: total,
      guests: guests,
      registered: registered,
      distinct_users: distinct_users
    }
  rescue
    _ ->
      %{total: 0, guests: 0, registered: 0, distinct_users: 0}
  end
end
