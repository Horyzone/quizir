defmodule Quizir.AccountsTest do
  use Quizir.DataCase

  alias Quizir.Accounts
  alias Quizir.Accounts.User
  import Quizir.AccountsFixtures

  describe "register_user/1" do
    test "creates a user with username and password only (no email)" do
      valid_attrs = %{
        username: unique_username(),
        password: valid_password()
      }

      assert {:ok, %User{} = user} = Accounts.register_user(valid_attrs)
      assert user.username == valid_attrs.username
      assert user.email == nil
      assert user.hashed_password != nil
      assert User.valid_password?(user, valid_attrs.password)
    end

    test "creates a user with username, password, and optional email" do
      valid_attrs = valid_user_attributes()

      assert {:ok, %User{} = user} = Accounts.register_user(valid_attrs)
      assert user.username == valid_attrs.username
      assert user.email == valid_attrs.email
      assert User.valid_password?(user, valid_attrs.password)
    end

    test "requires unique username" do
      username = unique_username()
      _user = user_fixture(%{username: username})

      assert {:error, %Ecto.Changeset{} = changeset} =
               Accounts.register_user(%{username: username, password: valid_password()})

      assert "has already been taken" in errors_on(changeset).username
    end

    test "validates username format" do
      assert {:error, changeset} =
               Accounts.register_user(%{username: "bad username!", password: valid_password()})

      assert "ne doit contenir que des lettres, chiffres, tirets et underscores" in errors_on(
               changeset
             ).username
    end

    test "validates password minimum length" do
      assert {:error, changeset} =
               Accounts.register_user(%{username: unique_username(), password: "123"})

      assert "should be at least 6 character(s)" in errors_on(changeset).password
    end

    test "validates email format if provided" do
      assert {:error, changeset} =
               Accounts.register_user(%{
                 username: unique_username(),
                 password: valid_password(),
                 email: "not-an-email"
               })

      assert "doit être une adresse email valide" in errors_on(changeset).email
    end
  end

  describe "authenticate user" do
    test "authenticates with valid username and password" do
      user = user_fixture()

      assert {:ok, auth_user} =
               Accounts.get_user_by_username_and_password(user.username, valid_password())

      assert auth_user.id == user.id
    end

    test "returns error with incorrect password" do
      user = user_fixture()

      assert {:error, :unauthorized} =
               Accounts.get_user_by_username_and_password(user.username, "wrongpass")
    end

    test "returns error with unknown username" do
      assert {:error, :unauthorized} =
               Accounts.get_user_by_username_and_password("unknown_user", "wrongpass")
    end
  end

  describe "sessions tokens" do
    test "generates, verifies and deletes session token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert is_binary(token)

      assert found_user = Accounts.get_user_by_session_token(token)
      assert found_user.id == user.id

      Accounts.delete_user_session_token(token)
      assert Accounts.get_user_by_session_token(token) == nil
    end
  end

  describe "password reset" do
    test "delivers instructions and resets password when user has email" do
      user = user_fixture()

      assert {:ok, email} =
               Accounts.deliver_user_reset_password_instructions(user, fn token ->
                 "https://example.com/reset/#{token}"
               end)

      assert email.to == [{user.username, user.email}]

      # Find token from email body
      [_, token] = Regex.run(~r/https:\/\/example.com\/reset\/([^\s]+)/, email.text_body)

      user_from_token = Accounts.get_user_by_reset_password_token(token)
      assert user_from_token.id == user.id

      new_password = "new_secret_password"

      assert {:ok, updated_user} =
               Accounts.reset_user_password(user_from_token, %{password: new_password})

      assert User.valid_password?(updated_user, new_password)
    end

    test "does not send reset email when user has no email" do
      user = user_fixture(%{email: nil})

      assert {:ok, :no_email_sent} =
               Accounts.deliver_user_reset_password_instructions(user, fn token ->
                 "https://example.com/reset/#{token}"
               end)
    end
  end

  describe "update_user_email/2" do
    test "updates user email with valid email" do
      user = user_fixture()
      new_email = "new_email@example.com"

      assert {:ok, updated_user} = Accounts.update_user_email(user, %{email: new_email})
      assert updated_user.email == new_email
    end

    test "allows setting email to empty string, which becomes nil" do
      user = user_fixture(%{email: "test@example.com"})

      assert {:ok, updated_user} = Accounts.update_user_email(user, %{email: ""})
      assert updated_user.email == nil
    end

    test "returns error with invalid email format" do
      user = user_fixture()

      assert {:error, changeset} = Accounts.update_user_email(user, %{email: "invalid-email"})
      assert "doit être une adresse email valide" in errors_on(changeset).email
    end
  end

  describe "update_user_password/2" do
    test "updates password with valid current_password and new password" do
      user = user_fixture()
      old_password = valid_password()
      new_password = "a_brand_new_secret"

      assert {:ok, updated_user} =
               Accounts.update_user_password(user, %{
                 "current_password" => old_password,
                 "password" => new_password,
                 "password_confirmation" => new_password
               })

      assert User.valid_password?(updated_user, new_password)
      refute User.valid_password?(updated_user, old_password)
    end

    test "returns error when current_password is wrong" do
      user = user_fixture()
      new_password = "a_brand_new_secret"

      assert {:error, changeset} =
               Accounts.update_user_password(user, %{
                 "current_password" => "wrong_password",
                 "password" => new_password,
                 "password_confirmation" => new_password
               })

      assert "est incorrect" in errors_on(changeset).current_password
    end

    test "returns error when password_confirmation does not match" do
      user = user_fixture()
      old_password = valid_password()

      assert {:error, changeset} =
               Accounts.update_user_password(user, %{
                 "current_password" => old_password,
                 "password" => "new_secret_1",
                 "password_confirmation" => "mismatching_secret"
               })

      assert "ne correspond pas au mot de passe" in errors_on(changeset).password_confirmation
    end
  end

  describe "deliver_user_reset_password_instructions/2" do
    import Swoosh.TestAssertions

    test "sends reset password email when user has email" do
      user = user_fixture(%{email: "user@example.com"})

      assert {:ok, email} =
               Accounts.deliver_user_reset_password_instructions(user, fn token ->
                 "https://example.com/reset/#{token}"
               end)

      assert email.to == [{user.username, "user@example.com"}]
      assert email.subject =~ "Réinitialisation de votre mot de passe"
      assert email.text_body =~ "https://example.com/reset/"
      assert email.html_body =~ "https://example.com/reset/"
      assert email.html_body =~ "Réinitialiser mon mot de passe"
      assert_email_sent(email)
    end

    test "does not send email when user has no email" do
      user = user_fixture(%{email: nil})

      assert {:ok, :no_email_sent} =
               Accounts.deliver_user_reset_password_instructions(user, fn token ->
                 "https://example.com/reset/#{token}"
               end)
    end

    test "finds user by email identifier (with trimming) and delivers email" do
      user = user_fixture(%{email: "findme@example.com"})

      assert {:ok, email} =
               Accounts.deliver_user_reset_password_instructions(
                 "  findme@example.com  ",
                 fn token ->
                   "https://example.com/reset/#{token}"
                 end
               )

      assert email.to == [{user.username, "findme@example.com"}]
      assert_email_sent(email)
    end

    test "finds user by username identifier and delivers email" do
      user = user_fixture(%{username: "resetuser", email: "user_by_name@example.com"})

      assert {:ok, email} =
               Accounts.deliver_user_reset_password_instructions("resetuser", fn token ->
                 "https://example.com/reset/#{token}"
               end)

      assert email.to == [{user.username, user.email}]
      assert_email_sent(email)
    end

    test "returns :no_email_sent when identifier does not exist" do
      assert {:ok, :no_email_sent} =
               Accounts.deliver_user_reset_password_instructions(
                 "nonexistent@example.com",
                 fn _ ->
                   "url"
                 end
               )
    end

    test "uses configured from_name and from_email in email" do
      user = user_fixture(%{email: "custom@example.com"})

      Application.put_env(:quizir, :mail_from_name, "Custom Quizir")
      Application.put_env(:quizir, :mail_from_address, "noreply@custom.com")

      on_exit(fn ->
        Application.delete_env(:quizir, :mail_from_name)
        Application.delete_env(:quizir, :mail_from_address)
      end)

      assert {:ok, email} =
               Accounts.deliver_user_reset_password_instructions(user, fn token ->
                 "https://example.com/reset/#{token}"
               end)

      assert email.from == {"Custom Quizir", "noreply@custom.com"}
      assert_email_sent(email)
    end

    test "format_error/1 humanizes complex SMTP and TLS errors" do
      alias Quizir.Accounts.UserNotifier

      err_incompatible = {:options, :incompatible, [verify: :verify_peer, cacerts: :undefined]}
      assert UserNotifier.format_error(err_incompatible) =~ "Incompatible SSL/TLS options"

      err_network =
        {:retries_exceeded, {:network_failure, ~c"smtp.example.com", {:error, err_incompatible}}}

      assert UserNotifier.format_error(err_network) =~ "Network failure connecting to"
      assert UserNotifier.format_error(err_network) =~ "Incompatible SSL/TLS options"

      err_tls = {:tls_alert, {:handshake_failure, ~c"handshake failed"}}
      assert UserNotifier.format_error(err_tls) =~ "TLS handshake failure"

      err_cert = {:bad_cert, :max_path_length_reached}
      assert UserNotifier.format_error(err_cert) =~ "max_path_length_reached"

      err_perm = {:permanent_failure, "mail.example.com", "550 User unknown"}
      assert UserNotifier.format_error(err_perm) =~ "Permanent SMTP server rejection"
    end
  end
end
