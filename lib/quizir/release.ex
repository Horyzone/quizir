defmodule Quizir.Release do
  @moduledoc """
  Utilities for production tasks, database migrations, and hot code reloading.
  """

  require Logger

  @doc """
  Runs database migrations programmatically.
  """
  def migrate do
    Application.ensure_all_started(:quizir)

    for repo <- Application.fetch_env!(:quizir, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    :ok
  end

  @doc """
  Rolls back database migrations programmatically.
  """
  def rollback(repo, version) do
    Application.ensure_all_started(:quizir)
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
    :ok
  end

  @doc """
  Hot-reloads all modified modules from disk into the running BEAM instance.
  This allows deploying code updates dynamically without restarting the container or dropping connections.
  """
  def reload_modules do
    modified = :code.modified_modules()

    Logger.info("[HotReload] Checking for modified modules on disk...")

    case modified do
      [] ->
        Logger.info("[HotReload] No modified modules detected.")
        refresh_static_manifest()
        {:ok, []}

      modules ->
        Logger.info(
          "[HotReload] Reloading #{length(modules)} modified module(s): #{inspect(modules)}"
        )

        case :code.atomic_load(modules) do
          :ok ->
            Logger.info(
              "[HotReload] Successfully reloaded #{length(modules)} module(s) into memory."
            )

            refresh_static_manifest()
            {:ok, modules}

          {:error, errors} ->
            Logger.error("[HotReload] Failed to atomic_load modules: #{inspect(errors)}")
            {:error, errors}
        end
    end
  end

  defp refresh_static_manifest do
    try do
      endpoint = QuizirWeb.Endpoint

      if function_exported?(endpoint, :config_change, 2) do
        endpoint.config_change([{:cache_static_manifest, "priv/static/cache_manifest.json"}], [])
        Logger.info("[HotReload] Static assets cache manifest refreshed.")
      end
    rescue
      err ->
        Logger.warning("[HotReload] Could not refresh static cache manifest: #{inspect(err)}")
    end
  end
end
