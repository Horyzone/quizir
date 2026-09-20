defmodule Quizir.Accounts.Scope do
  @moduledoc """
  Represents the current authentication scope.
  """
  defstruct [:user]

  @doc """
  Builds a scope struct for a given user.
  """
  def for_user(user) do
    %__MODULE__{user: user}
  end
end
