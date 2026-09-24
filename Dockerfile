# ==============================================================================
# Quizir - Dockerfile de Production pour Montage par Volume & Déploiement à Chaud
# ==============================================================================
# Cette image est conçue pour exécuter le projet monté en volume (-v $(pwd):/app).
# Aucun code source applicatif n'est copié dans l'image lors du build, ce qui permet
# de déployer des mises à jour dynamiquement sans redémarrer le conteneur.
# ==============================================================================

FROM elixir:1.20.4-otp-29-slim

# Paquets système essentiels :
# - build-essential : compilateur C/make requis pour pbkdf2_elixir (NIFs)
# - git : requis pour les dépendances git de mix (heroicons, daisyui)
# - curl & ca-certificates : requêtes HTTPS sécurisées et certificats SSL
# - inotify-tools : surveillance de fichiers pour le rechargement automatique
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      curl \
      ca-certificates \
      inotify-tools \
      ffmpeg \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Installation des gestionnaires de paquets Elixir / Erlang
RUN mix local.hex --force && \
    mix local.rebar --force

# Environnement par défaut
ENV MIX_ENV=prod
ENV PORT=4000
ENV PHX_SERVER=true

# Répertoire de travail où sera monté le volume du projet
WORKDIR /app

# Ports exposés :
# - 4000 : serveur web Phoenix
# - 4369 : EPMD pour la communication entre nœuds BEAM (déploiement à chaud)
EXPOSE 4000 4369

# Scripts d'initialisation et de déploiement à chaud
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY bin/deploy /usr/local/bin/deploy

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/deploy

# Copie du code source applicatif (écrasé si monté en volume)
COPY . /app

ENTRYPOINT ["entrypoint.sh"]
CMD ["start"]
