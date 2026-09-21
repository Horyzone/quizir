defmodule Quizir.ReleaseTest do
  use ExUnit.Case, async: false

  alias Quizir.Release

  test "reload_modules/0 executes without error" do
    assert {:ok, _modules} = Release.reload_modules()
  end
end
