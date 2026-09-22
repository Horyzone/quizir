defmodule Quizir.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Query

  @session_validity_in_days 60
  @reset_password_validity_in_hours 2

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string

    belongs_to :user, Quizir.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Generates a session token for the user.
  """
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(32)
    {token, %__MODULE__{token: token, context: "session", user_id: user.id}}
  end

  @doc """
  Verifies a session token.
  Returns query that finds the user.
  """
  def verify_session_token_query(token) do
    from token in by_token_and_context_query(token, "session"),
      join: user in assoc(token, :user),
      where: token.inserted_at > ago(@session_validity_in_days, "day"),
      select: user
  end

  @admin_session_validity_in_days 14

  @doc """
  Generates an admin session token for the user.
  """
  def build_admin_session_token(user) do
    token = :crypto.strong_rand_bytes(32)
    {token, %__MODULE__{token: token, context: "admin_session", user_id: user.id}}
  end

  @doc """
  Verifies an admin session token.
  Returns query that finds the user only if they are an administrator.
  """
  def verify_admin_session_token_query(token) do
    from token in by_token_and_context_query(token, "admin_session"),
      join: user in assoc(token, :user),
      where: user.admin == true,
      where: token.inserted_at > ago(@admin_session_validity_in_days, "day"),
      select: user
  end

  @doc """
  Generates a reset password token for the user.
  """
  def build_email_token(user, context) do
    token = :crypto.strong_rand_bytes(32)
    url_token = Base.url_encode64(token, padding: false)
    hashed_token = :crypto.hash(:sha256, token)

    {url_token,
     %__MODULE__{
       token: hashed_token,
       context: context,
       sent_to: user.email,
       user_id: user.id
     }}
  end

  @doc """
  Verifies an email token (e.g., reset_password).
  Returns query that finds the user.
  """
  def verify_email_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(:sha256, decoded_token)

        from token in by_token_and_context_query(hashed_token, context),
          join: user in assoc(token, :user),
          where: token.inserted_at > ago(@reset_password_validity_in_hours, "hour"),
          select: user

      _ ->
        :error
    end
  end

  def by_token_and_context_query(token, context) do
    from __MODULE__, where: [token: ^token, context: ^context]
  end

  def by_user_and_contexts_query(user, :all) do
    from __MODULE__, where: [user_id: ^user.id]
  end

  def by_user_and_contexts_query(user, contexts) when is_list(contexts) do
    from t in __MODULE__, where: t.user_id == ^user.id and t.context in ^contexts
  end
end
