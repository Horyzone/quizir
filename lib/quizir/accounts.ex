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
end
