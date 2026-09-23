#!/usr/bin/env bash
set -e

APP_DIR="${APP_DIR:-/app}"

if [ ! -f "$APP_DIR/mix.exs" ]; then
  echo "============================================================"
  echo "[ERREUR] Aucun projet Phoenix détecté dans $APP_DIR !"
  echo "Vous devez monter le code de votre projet via un volume Docker :"
  echo "    docker run -v \$(pwd):/app -p 4000:4000 quizir"
  echo "Ou avec Docker Compose :"
  echo "    volumes:"
  echo "      - .:/app"
  echo "============================================================"
  exit 1
fi

cd "$APP_DIR"

export MIX_ENV="${MIX_ENV:-prod}"
export PORT="${PORT:-4000}"
export PHX_SERVER="${PHX_SERVER:-true}"
export NODE_COOKIE="${NODE_COOKIE:-quizir_node_cookie}"

# Handle subcommands like 'deploy', 'sh', 'bash', 'test'
if [ "$1" = "deploy" ]; then
  shift
  exec deploy "$@"
elif [ "$1" = "sh" ] || [ "$1" = "bash" ]; then
  exec "$@"
elif [ "$1" != "start" ] && [ -n "$1" ]; then
  exec "$@"
fi

echo "============================================================"
echo "  Démarrage de Quizir en mode Production (Volume partagé)   "
echo "============================================================"
echo "  Environnement : $MIX_ENV"
echo "  Port HTTP     : $PORT"
echo "  Répertoire    : $APP_DIR"
echo "============================================================"

echo "==> [1/4] Vérification des dépendances..."
mix deps.get --only "$MIX_ENV"

echo "==> [2/4] Compilation de l'application..."
mix compile

echo "==> [3/4] Compilation des assets statiques (Tailwind & JS)..."
mix assets.deploy

# Wait for database if DATABASE_URL is defined
if [ -n "$DATABASE_URL" ]; then
  echo "==> Attente de la disponibilité de la base de données..."
  until mix run -e '
    case Quizir.Repo.start_link() do
      {:ok, _} -> System.halt(0)
      {:error, {:already_started, _}} -> System.halt(0)
      _ -> System.halt(1)
    end
  ' 2>/dev/null; do
    echo "    La base de données n'est pas encore prête, nouvelle tentative dans 2s..."
    sleep 2
  done
  echo "==> Base de données connectée !"

  echo "==> [4/4] Exécution des migrations..."
  mix ecto.migrate
else
  echo "==> [4/4] DATABASE_URL non défini à ce stade, migrations différées."
fi

# Trap SIGHUP signal to trigger hot reload: docker kill -s HUP <container>
trap 'echo "==> Signal SIGHUP reçu, rechargement à chaud..."; deploy' HUP

# Automatic file watcher if AUTO_RELOAD=true
if [ "$AUTO_RELOAD" = "true" ] || [ "$AUTO_RELOAD" = "1" ]; then
  echo "==> Surveillance automatique des fichiers activée (AUTO_RELOAD=true)..."
  (
    while true; do
      inotifywait -r -q -e modify,create,delete,move "$APP_DIR/lib" "$APP_DIR/assets" "$APP_DIR/config" 2>/dev/null || true
      sleep 2
      while inotifywait -r -q -t 1 -e modify,create,delete,move "$APP_DIR/lib" "$APP_DIR/assets" "$APP_DIR/config" 2>/dev/null; do
        sleep 1
      done
      echo "==> Modification détectée sur le volume, déploiement à chaud en cours..."
      deploy || true
    done
  ) &
fi

echo "==> Lancement du serveur Phoenix (nœud distribué pour rechargement dynamique)..."
exec elixir --sname quizir --cookie "$NODE_COOKIE" -S mix phx.server
