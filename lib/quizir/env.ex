defmodule Quizir.Env do
  @moduledoc """
  Utilities to load and parse `.env` files into the BEAM's system environment.
  """

  @doc """
  Loads environment files into `System.put_env/2`.
  Preserves any environment variables already set in the OS environment.
  """
  def load(opts \\ []) do
    config_env = Keyword.get(opts, :config_env, default_env())
    root_dirs = Keyword.get(opts, :root_dirs, default_root_dirs())
    existing_env = System.get_env()

    filenames = [
      ".env",
      ".env.#{config_env}",
      ".env.local",
      ".env.#{config_env}.local"
    ]

    env_files =
      for dir <- root_dirs,
          name <- filenames do
        Path.join(dir, name)
      end
      |> Enum.uniq()

    parsed_vars =
      Enum.reduce(env_files, %{}, fn file, acc ->
        Map.merge(acc, load_file(file))
      end)

    Enum.each(parsed_vars, fn {key, val} ->
      if not Map.has_key?(existing_env, key) or existing_env[key] == "" do
        System.put_env(key, val)
      end
    end)

    {:ok, parsed_vars}
  end

  @doc """
  Loads a single `.env` file from the given path.
  Returns a map of key-value pairs, or an empty map if the file does not exist.
  """
  def load_file(path) do
    if File.exists?(path) do
      path
      |> File.read!()
      |> parse()
    else
      %{}
    end
  end

  @doc """
  Parses a dotenv-formatted string into a map of key-value pairs.
  """
  def parse(content) when is_binary(content) do
    content
    |> String.split(["\r\n", "\n"])
    |> Enum.reduce(%{}, fn line, acc ->
      line = String.trim(line)

      cond do
        line == "" or String.starts_with?(line, "#") ->
          acc

        true ->
          line =
            if String.starts_with?(line, "export ") do
              String.replace_prefix(line, "export ", "") |> String.trim()
            else
              line
            end

          case String.split(line, "=", parts: 2) do
            [key, val] ->
              key = String.trim(key)
              val = parse_value(String.trim(val))
              Map.put(acc, key, val)

            _ ->
              acc
          end
      end
    end)
  end

  defp parse_value(val) do
    cond do
      String.starts_with?(val, "\"") and String.ends_with?(val, "\"") and String.length(val) >= 2 ->
        val
        |> String.slice(1..-2//1)
        |> String.replace("\\n", "\n")
        |> String.replace("\\r", "\r")
        |> String.replace("\\t", "\t")
        |> String.replace("\\\"", "\"")
        |> String.replace("\\\\", "\\")

      String.starts_with?(val, "'") and String.ends_with?(val, "'") and String.length(val) >= 2 ->
        String.slice(val, 1..-2//1)

      true ->
        case String.split(val, ~r/\s+#/, parts: 2) do
          [clean_val, _comment] -> String.trim(clean_val)
          [clean_val] -> clean_val
        end
    end
  end

  defp default_env do
    if function_exported?(Mix, :env, 0), do: Mix.env(), else: :prod
  end

  defp default_root_dirs do
    [
      File.cwd!(),
      Path.expand("../..", __DIR__)
    ]
    |> Enum.uniq()
  end
end
