defmodule QuizirWeb.Router do
  use QuizirWeb, :router

  import QuizirWeb.UserAuth
  import QuizirWeb.AdminAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QuizirWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :fetch_current_admin_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Authentication routes for unauthenticated users
  scope "/", QuizirWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{QuizirWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  # Routes requiring authentication
  scope "/", QuizirWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{QuizirWeb.UserAuth, :ensure_authenticated}] do
      live "/quizzes/new", QuizLive.Form, :new
      live "/quizzes/:id/edit", QuizLive.Form, :edit
      live "/my-quizzes", QuizLive.MyQuizzes, :index
      live "/users/settings", UserSettingsLive, :edit
    end
  end

  # General routes (with current user mounted if present)
  scope "/", QuizirWeb do
    pipe_through :browser

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{QuizirWeb.UserAuth, :mount_current_user}] do
      live "/", HomeLive, :index
      live "/quizzes", QuizLive.Index, :index
      live "/quizzes/:id", QuizLive.Show, :show

      # Routes Jeux Multijoueur
      live "/games", GameLive.Index, :index
      live "/join", GameLive.Join, :join
      live "/games/:code", GameLive.Play, :play
    end
  end

  # Admin authentication routes
  scope "/admin", QuizirWeb do
    pipe_through [:browser, :redirect_if_admin_is_authenticated]

    live_session :redirect_if_admin_is_authenticated,
      on_mount: [{QuizirWeb.AdminAuth, :redirect_if_admin_is_authenticated}] do
      live "/log_in", AdminLoginLive, :new
    end

    post "/log_in", AdminSessionController, :create
  end

  # Admin management routes requiring admin authentication
  scope "/admin", QuizirWeb do
    pipe_through [:browser, :require_authenticated_admin]

    delete "/log_out", AdminSessionController, :delete

    live_session :require_authenticated_admin,
      on_mount: [{QuizirWeb.AdminAuth, :ensure_authenticated_admin}] do
      live "/", Admin.DashboardLive, :index
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:quizir, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: QuizirWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
