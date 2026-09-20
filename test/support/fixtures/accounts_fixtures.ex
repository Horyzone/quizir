defmodule Quizir.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Quizir.Accounts` context.
  """

  def unique_username, do: "user_#{System.unique_integer([:positive])}"
  def unique_email, do: "user_#{System.unique_integer([:positive])}@example.com"
  def valid_password, do: "secret12345"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      username: unique_username(),
      email: unique_email(),
      password: valid_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Quizir.Accounts.register_user()

    user
  end
end
