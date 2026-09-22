defmodule QuizirWeb.InitialSetupTest do
  use QuizirWeb.ConnCase

  alias Quizir.Accounts

  describe "Initial admin setup enforcement" do
    setup do
      Application.put_env(:quizir, :force_initial_admin_setup, true)
      on_exit(fn -> Application.put_env(:quizir, :force_initial_admin_setup, false) end)
      :ok
    end

    test "Accounts.register_initial_admin/1 creates admin user when 0 users exist", %{conn: _conn} do
      assert Accounts.count_users() == 0

      attrs = %{
        username: "superadmin",
        password: "superpassword123",
        email: "superadmin@example.com"
      }

      assert {:ok, user} = Accounts.register_initial_admin(attrs)
      assert user.admin == true
      assert user.username == "superadmin"

      # Second call fails because an admin already exists
      assert {:error, :initial_admin_already_exists} =
               Accounts.register_initial_admin(%{
                 username: "secondadmin",
                 password: "superpassword123"
               })
    end

    test "redirects public pages to /users/register when 0 users exist in DB", %{conn: conn} do
      assert Accounts.count_users() == 0

      # Visiting home redirects to register
      assert {:error, {:redirect, %{to: "/users/register"}}} = live(conn, ~p"/")

      # Visiting quizzes redirects to register
      assert {:error, {:redirect, %{to: "/users/register"}}} = live(conn, ~p"/quizzes")

      # Visiting admin login redirects to register
      assert {:error, {:redirect, %{to: "/users/register"}}} = live(conn, ~p"/admin/log_in")

      # Visiting user login redirects to register
      assert {:error, {:redirect, %{to: "/users/register"}}} = live(conn, ~p"/users/log_in")
    end

    test "renders initial setup form on /users/register when 0 users exist", %{conn: conn} do
      assert Accounts.count_users() == 0

      {:ok, view, html} = live(conn, ~p"/users/register")

      assert has_element?(view, "#initial-setup-badge", "Configuration initiale")
      assert has_element?(view, "#initial-admin-notice")
      assert has_element?(view, "#registration-title", "Premier compte Quizir")
      assert html =~ "droits administrateur"
      assert has_element?(view, "#register-submit-btn", "Créer le compte administrateur")

      # Link to login is hidden since no account exists
      refute has_element?(view, "a[href='/users/log_in']", "Se connecter")
    end

    test "submitting initial setup form creates admin user and unblocks the application", %{
      conn: conn
    } do
      assert Accounts.count_users() == 0

      {:ok, view, _html} = live(conn, ~p"/users/register")

      # Submit the registration form
      view
      |> form("#registration_form", %{
        "user" => %{
          "username" => "premieradmin",
          "email" => "admin@quizir.local",
          "password" => "adminpass123"
        }
      })
      |> render_submit()

      # Verify user created with admin privileges
      created_user = Accounts.get_user_by_username("premieradmin")
      assert created_user != nil
      assert created_user.admin == true
      assert Accounts.count_users() == 1

      # Application is now unblocked
      conn = build_conn()
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "quiz en direct"

      # Future registrations are normal (not initial setup)
      {:ok, view2, _html} = live(conn, ~p"/users/register")
      refute has_element?(view2, "#initial-setup-badge")
      refute has_element?(view2, "#initial-admin-notice")
      assert has_element?(view2, "#registration-title", "Créer un compte")
      assert has_element?(view2, "a[href='/users/log_in']", "Se connecter")

      # Second registered user is not admin
      view2
      |> form("#registration_form", %{
        "user" => %{
          "username" => "joueur_lambda",
          "password" => "joueurpass123"
        }
      })
      |> render_submit()

      second_user = Accounts.get_user_by_username("joueur_lambda")
      assert second_user != nil
      assert second_user.admin == false
    end
  end
end
