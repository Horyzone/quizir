defmodule Quizir.Repo.Migrations.AddTotpToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :totp_enabled, :boolean, default: false, null: false
      add :totp_secret, :binary
    end
  end
end
