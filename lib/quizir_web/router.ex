defmodule QuizirWeb.Router do
  use QuizirWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QuizirWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", QuizirWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Routes Quizir
    live "/quizzes", QuizLive.Index, :index
    live "/quizzes/new", QuizLive.Form, :new
    live "/quizzes/:id", QuizLive.Show, :show
    live "/quizzes/:id/edit", QuizLive.Form, :edit
  end

  # Other scopes may use custom stacks.
  # scope "/api", QuizirWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:quizir, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: QuizirWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
