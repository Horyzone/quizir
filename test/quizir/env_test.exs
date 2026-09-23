defmodule Quizir.EnvTest do
  use ExUnit.Case, async: false

  alias Quizir.Env

  describe "parse/1" do
    test "parses simple key=value pairs" do
      content = """
      FOO=bar
      HELLO=world
      """

      assert Env.parse(content) == %{
               "FOO" => "bar",
               "HELLO" => "world"
             }
    end

    test "ignores comments and blank lines" do
      content = """
      # This is a comment
      FOO=bar

      # Another comment
      BAZ=qux
      """

      assert Env.parse(content) == %{
               "FOO" => "bar",
               "BAZ" => "qux"
             }
    end

    test "supports export prefix" do
      content = """
      export SMTP_HOST=smtp.example.com
      export PORT=4000
      """

      assert Env.parse(content) == %{
               "SMTP_HOST" => "smtp.example.com",
               "PORT" => "4000"
             }
    end

    test "handles double quoted values with escaped characters and internal hashes" do
      content = """
      SECRET="my#secret#password"
      GREETING="hello\\nworld"
      QUOTED="he said \\"hello\\""
      """

      assert Env.parse(content) == %{
               "SECRET" => "my#secret#password",
               "GREETING" => "hello\nworld",
               "QUOTED" => "he said \"hello\""
             }
    end

    test "handles single quoted values without escape expansion" do
      content = """
      RAW='literal\\nvalue'
      HASH='pass#word'
      """

      assert Env.parse(content) == %{
               "RAW" => "literal\\nvalue",
               "HASH" => "pass#word"
             }
    end

    test "strips trailing comments from unquoted values" do
      content = """
      PORT=4000 # default web port
      DEBUG=true # enable debug
      URL=http://localhost:4000#section
      """

      # The URL without space before # is preserved
      assert Env.parse(content) == %{
               "PORT" => "4000",
               "DEBUG" => "true",
               "URL" => "http://localhost:4000#section"
             }
    end

    test "handles values containing multiple equal signs" do
      content = """
      DATABASE_URL=ecto://user:pass@localhost:5432/my_db?ssl=true
      """

      assert Env.parse(content) == %{
               "DATABASE_URL" => "ecto://user:pass@localhost:5432/my_db?ssl=true"
             }
    end

    test "handles empty values" do
      content = """
      EMPTY=
      SPACES=
      """

      assert Env.parse(content) == %{
               "EMPTY" => "",
               "SPACES" => ""
             }
    end
  end

  describe "load/1" do
    test "loads values into System environment without overwriting pre-existing OS vars" do
      var_os = "QUIZIR_TEST_OS_VAR_#{System.unique_integer([:positive])}"
      var_file = "QUIZIR_TEST_FILE_VAR_#{System.unique_integer([:positive])}"

      System.put_env(var_os, "os_value")

      on_exit(fn ->
        System.delete_env(var_os)
        System.delete_env(var_file)
      end)

      tmp_dir =
        Path.join(System.tmp_dir!(), "quizir_env_test_#{System.unique_integer([:positive])}")

      File.mkdir_p!(tmp_dir)

      on_exit(fn ->
        File.rm_rf!(tmp_dir)
      end)

      File.write!(Path.join(tmp_dir, ".env"), """
      #{var_os}=file_value
      #{var_file}=from_env_file
      """)

      {:ok, vars} = Env.load(root_dirs: [tmp_dir], config_env: :test)

      assert vars[var_os] == "file_value"
      assert vars[var_file] == "from_env_file"

      # Pre-existing OS variable was preserved
      assert System.get_env(var_os) == "os_value"
      # New variable was populated into System environment
      assert System.get_env(var_file) == "from_env_file"
    end

    test "environment-specific and local files take precedence" do
      var_key = "QUIZIR_PRECEDENCE_VAR_#{System.unique_integer([:positive])}"

      on_exit(fn ->
        System.delete_env(var_key)
      end)

      tmp_dir =
        Path.join(
          System.tmp_dir!(),
          "quizir_env_precedence_#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(tmp_dir)

      on_exit(fn ->
        File.rm_rf!(tmp_dir)
      end)

      File.write!(Path.join(tmp_dir, ".env"), "#{var_key}=base_value\n")
      File.write!(Path.join(tmp_dir, ".env.local"), "#{var_key}=local_override\n")

      {:ok, _} = Env.load(root_dirs: [tmp_dir], config_env: :dev)

      assert System.get_env(var_key) == "local_override"
    end
  end

  describe "Project .env integration" do
    test "loads .env variables into System.get_env/1" do
      if File.exists?(".env") do
        # When .env exists in workspace, assert that variables are loaded into System.get_env/1
        assert System.get_env("SMTP_HOST") != nil
      else
        # When running in environments without a workspace .env (e.g. CI or fresh checkout),
        # verify that loading .env.example or a temporary env file populates System environment
        tmp_dir =
          Path.join(System.tmp_dir!(), "quizir_env_proj_#{System.unique_integer([:positive])}")

        File.mkdir_p!(tmp_dir)

        on_exit(fn ->
          File.rm_rf!(tmp_dir)
          System.delete_env("QUIZIR_PROJECT_TEST_VAR")
        end)

        File.write!(Path.join(tmp_dir, ".env"), "QUIZIR_PROJECT_TEST_VAR=loaded_ok\n")
        {:ok, vars} = Env.load(root_dirs: [tmp_dir], config_env: :test)

        assert vars["QUIZIR_PROJECT_TEST_VAR"] == "loaded_ok"
        assert System.get_env("QUIZIR_PROJECT_TEST_VAR") == "loaded_ok"
      end
    end
  end
end
