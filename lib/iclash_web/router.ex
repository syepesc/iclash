defmodule IclashWeb.Router do
  use IclashWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {IclashWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :dashboard_auth do
    plug :dashboard_auth_fn
  end

  scope "/", IclashWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", IclashWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  import Phoenix.LiveDashboard.Router

  scope "/dev" do
    pipe_through [:browser, :dashboard_auth]

    live_dashboard "/dashboard", metrics: IclashWeb.Telemetry
    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end

  defp dashboard_auth_fn(conn, _opts) do
    username = System.fetch_env!("DASHBOARD_USERNAME")
    password = System.fetch_env!("DASHBOARD_PASSWORD")
    Plug.BasicAuth.basic_auth(conn, username: username, password: password)
  end
end
