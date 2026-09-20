defmodule Quizir.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :password_confirmation, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true

    has_many :quizzes, Quizir.Quizzes.Quiz, on_delete: :nilify_all
    has_many :tokens, Quizir.Accounts.UserToken, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.
  Username and password are required. Email is optional.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:username, :email, :password])
    |> validate_username()
    |> validate_email()
    |> validate_password(opts)
  end

  @doc """
  A user changeset for updating email.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
  end

  @doc """
  A user changeset for changing password (e.g., reset).
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_password(opts)
  end

  @doc """
  A user changeset for changing password with current password verification.
  """
  def password_update_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password, :password_confirmation, :current_password])
    |> validate_required([:current_password, :password])
    |> validate_confirmation(:password, message: "ne correspond pas au mot de passe")
    |> validate_password(opts)
    |> validate_current_password()
  end

  defp validate_current_password(changeset) do
    current_password = get_change(changeset, :current_password)

    if current_password && valid_password?(changeset.data, current_password) do
      changeset
    else
      if current_password do
        add_error(changeset, :current_password, "est incorrect")
      else
        changeset
      end
    end
  end

  defp validate_username(changeset) do
    changeset
    |> validate_required([:username])
    |> update_change(:username, &String.trim/1)
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/,
      message: "ne doit contenir que des lettres, chiffres, tirets et underscores"
    )
    |> unsafe_validate_unique(:username, Quizir.Repo)
    |> unique_constraint(:username)
  end

  defp validate_email(changeset) do
    email = get_change(changeset, :email)

    if email && String.trim(email) != "" do
      changeset
      |> update_change(:email, &String.trim/1)
      |> validate_length(:email, max: 160)
      |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
        message: "doit être une adresse email valide"
      )
      |> unsafe_validate_unique(:email, Quizir.Repo)
      |> unique_constraint(:email)
    else
      # If email is empty string or whitespace, set it to nil
      put_change(changeset, :email, nil)
    end
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 6, max: 72)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # Hashing password using Pbkdf2
      |> put_change(:hashed_password, Pbkdf2.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Verifies the password.
  Returns boolean.
  """
  def valid_password?(%Quizir.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and is_binary(password) do
    Pbkdf2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Pbkdf2.no_user_verify()
    false
  end
end
