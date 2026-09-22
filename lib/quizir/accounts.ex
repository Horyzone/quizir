defmodule Quizir.Accounts do
  @moduledoc """
  The Accounts context.
  """

  require Logger
  import Ecto.Query, warn: false
  alias Quizir.Repo

  alias Quizir.Accounts.{User, UserNotifier, UserToken}

  @doc """
  Gets a single user by ID. Raises Ecto.NoResultsError if not found.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user by ID. Returns nil if not found.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a user by username (case-insensitive).
  """
  def get_user_by_username(username) when is_binary(username) do
    clean_username = String.trim(username)

    from(u in User, where: fragment("lower(?) = lower(?)", u.username, ^clean_username))
    |> Repo.one()
  end

  def get_user_by_username(_), do: nil

  @doc """
  Gets a user by email (case-insensitive).
  """
  def get_user_by_email(email) when is_binary(email) do
    clean_email = String.trim(email)

    if clean_email != "" do
      from(u in User, where: fragment("lower(?) = lower(?)", u.email, ^clean_email))
      |> Repo.one()
    else
      nil
    end
  end

  def get_user_by_email(_), do: nil

  @doc """
  Gets a user by username and authenticates with password.
  Returns `{:ok, user}` or `{:error, :unauthorized}`.
  """
  def get_user_by_username_and_password(username, password)
      when is_binary(username) and is_binary(password) do
    user = get_user_by_username(username)

    if User.valid_password?(user, password) do
      {:ok, user}
    else
      {:error, :unauthorized}
    end
  end

  def get_user_by_username_and_password(_, _), do: {:error, :unauthorized}

  @doc """
  Registers a new user.
  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user registration changes.
  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false)
  end

  ## Session Tokens

  @doc """
  Generates a session token for the user.
  """
  def generate_user_session_token(%User{} = user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) when is_binary(token) do
    Repo.one(UserToken.verify_session_token_query(token))
  end

  def get_user_by_session_token(_), do: nil

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) when is_binary(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Reset Password

  @doc """
  Delivers the reset password email to the given user if they have an email registered.
  Accepts either a %User{} or an identifier (email or username).
  """
  def deliver_user_reset_password_instructions(identifier, reset_password_url_fun)
      when is_binary(identifier) do
    identifier = String.trim(identifier)
    user = get_user_by_email(identifier) || get_user_by_username(identifier)

    if user && user.email do
      deliver_user_reset_password_instructions(user, reset_password_url_fun)
    else
      if is_nil(user) do
        Logger.info(
          "[Mailer] Password reset requested for non-existent identifier: #{inspect(identifier)}"
        )
      else
        Logger.warning(
          "[Mailer] Password reset requested for user '#{user.username}' but no email address is registered."
        )
      end

      # Do not leak whether user or email exists
      {:ok, :no_email_sent}
    end
  end

  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    if user.email do
      {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
      Repo.insert!(user_token)

      UserNotifier.deliver_reset_password_instructions(
        user,
        reset_password_url_fun.(encoded_token)
      )
    else
      {:ok, :no_email_sent}
    end
  end

  @doc """
  Gets the user by reset password token.
  """
  def get_user_by_reset_password_token(token) when is_binary(token) do
    case UserToken.verify_email_token_query(token, "reset_password") do
      %Ecto.Query{} = query -> Repo.one(query)
      :error -> nil
    end
  end

  def get_user_by_reset_password_token(_), do: nil

  @doc """
  Resets the user password.
  """
  def reset_user_password(%User{} = user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Returns a changeset for changing the user password.
  """
  def change_user_password(%User{} = user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates user email.
  """
  def update_user_email(%User{} = user, attrs) do
    user
    |> User.email_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a changeset for changing the user email.
  """
  def change_user_email(%User{} = user, attrs \\ %{}) do
    User.email_changeset(user, attrs)
  end

  @doc """
  Updates the user password after validating the current password.
  """
  def update_user_password(%User{} = user, attrs) do
    user
    |> User.password_update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a changeset for updating the user password in account settings.
  """
  def change_user_password_update(%User{} = user, attrs \\ %{}) do
    User.password_update_changeset(user, attrs, hash_password: false)
  end

  ## Admin Session & Management

  @doc """
  Generates an admin session token for an administrator user.
  Returns token binary on success, nil if user is not admin.
  """
  def generate_admin_session_token(%User{admin: true} = user) do
    {token, user_token} = UserToken.build_admin_session_token(user)
    Repo.insert!(user_token)
    token
  end

  def generate_admin_session_token(_), do: nil

  @doc """
  Gets the user by admin session token.
  Only returns the user if token is valid and user is still an admin.
  """
  def get_user_by_admin_session_token(token) when is_binary(token) do
    UserToken.verify_admin_session_token_query(token)
    |> Repo.one()
  end

  def get_user_by_admin_session_token(_), do: nil

  @doc """
  Deletes the admin session token.
  """
  def delete_admin_session_token(token) when is_binary(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "admin_session"))
    :ok
  end

  def delete_admin_session_token(_), do: :ok

  @doc """
  Lists users with optional search filter (search by username or email).
  """
  def list_users(opts \\ []) do
    search = Keyword.get(opts, :search, "") |> to_string() |> String.trim()

    query =
      from u in User,
        order_by: [desc: u.inserted_at, desc: u.id]

    query =
      if search != "" do
        pattern = "%#{search}%"
        from u in query, where: ilike(u.username, ^pattern) or ilike(u.email, ^pattern)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Counts total registered users.
  """
  def count_users do
    Repo.aggregate(User, :count, :id) || 0
  end

  @doc """
  Counts total admin users.
  """
  def count_admins do
    from(u in User, where: u.admin == true)
    |> Repo.aggregate(:count, :id)
    |> Kernel.||(0)
  end

  @doc """
  Counts total regular player users.
  """
  def count_players do
    from(u in User, where: u.admin == false)
    |> Repo.aggregate(:count, :id)
    |> Kernel.||(0)
  end

  @doc """
  Counts users who have registered an email address.
  """
  def count_users_with_email do
    from(u in User, where: not is_nil(u.email) and u.email != "")
    |> Repo.aggregate(:count, :id)
    |> Kernel.||(0)
  end

  @doc """
  Counts users without an email address (username only).
  """
  def count_users_without_email do
    count_users() - count_users_with_email()
  end

  @doc """
  Updates a user's admin status.
  Prevents removing admin status from oneself.
  """
  def update_user_admin(%User{} = user, is_admin, %User{} = current_admin)
      when is_boolean(is_admin) do
    if user.id == current_admin.id and not is_admin do
      {:error, :cannot_demote_self}
    else
      user
      |> User.admin_changeset(%{admin: is_admin})
      |> Repo.update()
      |> case do
        {:ok, _updated_user} = result ->
          if not is_admin do
            Repo.delete_all(UserToken.by_user_and_contexts_query(user, ["admin_session"]))
          end

          result

        error ->
          error
      end
    end
  end

  @doc """
  Deletes a user account by an admin.
  Prevents an admin from deleting their own account.
  """
  def delete_user_by_admin(%User{} = user, %User{} = current_admin) do
    if user.id == current_admin.id do
      {:error, :cannot_delete_self}
    else
      Repo.delete(user)
    end
  end
end
