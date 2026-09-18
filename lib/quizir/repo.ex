defmodule Quizir.Repo do
  use Ecto.Repo,
    otp_app: :quizir,
    adapter: Ecto.Adapters.Postgres
end
