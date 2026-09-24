# Quizir

<div align="center">

[![Version](https://img.shields.io/github/v/tag/Horyzone/quizir?style=for-the-badge&label=version)](https://github.com/Horyzone/quizir/releases)
![Elixir](https://img.shields.io/badge/Elixir-1.18%2B-purple.svg?style=for-the-badge&logo=elixir)
![Phoenix](https://img.shields.io/badge/Phoenix-v1.8%2B-orange.svg?style=for-the-badge&logo=phoenixframework)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg?style=for-the-badge&logo=docker)
![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)
[![CI - Tests](https://github.com/Horyzone/quizir/actions/workflows/ci.yml/badge.svg)](https://github.com/Horyzone/quizir/actions/workflows/ci.yml)

**Plateforme web de quiz multijoueurs synchronisés en temps réel développée avec Elixir et Phoenix LiveView.**

[Fonctionnalités](#fonctionnalités-et-parcours-utilisateur) • [Aspects Techniques](#architecture-technique) • [Installation Docker](#installation-avec-docker) • [Stockage S3](#configuration-du-stockage-s3-pour-les-images-optionnel) • [Développement Local](#démarrage-en-développement-local) • [Engagements Éthiques](#protection-des-données--engagements-légaux)

</div>

---

## Présentation du projet

**Quizir** est une application web moderne et interactive permettant de concevoir des quiz et d'organiser des parties multijoueurs synchronisées en direct. À la manière des plateformes de quiz en ligne populaires, les participants rejoignent une salle de jeu via un code PIN court sur leur téléphone ou ordinateur, répondent à des questions avec compte à rebours, et découvrent les classements instantanément mis à jour.

> **Vocation démonstrative :** Quizir a été conçu comme une vitrine technologique et un démonstrateur de compétences en ingénierie logicielle (architecture réactive OTP, concurrence BEAM, temps réel avec Phoenix LiveView et communication WebSocket). La plateforme est **strictement non commerciale**.

---

## Fonctionnalités et parcours utilisateur

### 1. Visiteur & Joueur Invité (*Guest*)
- **Rejoindre en un clic :** Aucun compte requis. Il suffit de renseigner le code PIN de la partie et un pseudonyme depuis la page d'accueil ou `/join`.
- **Expérience de jeu temps réel :**
  - Compte à rebours synchronisé pour chaque question.
  - Soumission instantanée des réponses.
  - Calcul dynamique du score fondé sur la justesse et la vitesse de réaction.
  - Immersion sonore : clics interactifs, son de révélation des réponses et musiques d'ambiance aléatoires.
- **Podium & Résultats :** Affichage du score individuel et du classement final de la session.

### 2. Créateur de Quiz & Organisateur
- **Authentification sécurisée :** Création de compte avec mot de passe haché par PBKDF2.
- **Gestion des quiz :**
  - Création, édition et suppression de quiz.
  - Visibilité paramétrable : **public** (visible dans l'explorateur) ou **privé** (accessible sur code ou invitation).
  - Gestion détaillée des questions : énoncé, chronomètre personnalisable par question (secondes), choix multiples et désignation des bonnes réponses.
- **Animation de salon (Lobby) :**
  - Génération d'un code PIN unique à 6 caractères.
  - Suivi en direct des joueurs qui rejoignent la salle d'attente.
  - **Rôle d'hôte flexible :** L'organisateur peut participer en tant que joueur ou rester simple animateur/régisseur (dans ce cas, les boutons de réponses sont grisés pour lui et un bandeau dédié l'avertit).

### 3. Espace Administration
- **Dashboard temps réel :**
  - Statistiques en direct : parties actives en mémoire vive, parties terminées, utilisateurs inscrits et invités connectés.
  - Répartition des quiz publics et privés.
  - Surveillance des sessions de jeu en cours.
- **Initial Setup automatisé :** À l'installation, si aucun compte n'existe en base de données, l'application redirige automatiquement vers le formulaire d'initialisation du premier compte administrateur.

---

## Architecture technique

L'application repose sur l'écosystème **Elixir / Phoenix**, réputé pour sa haute tolérance aux pannes et ses performances exceptionnelles en temps réel :

### Composants principaux
* **Elixir 1.18+ & OTP (BEAM) :** Gestion de la concurrence par passage de messages entre processus légers et isolés.
* **Phoenix Framework 1.8+ avec Bandit :** Serveur HTTP/WebSocket rapide et économe en ressources.
* **Phoenix LiveView 1.x :** Interfaces réactives sans framework JavaScript lourd côté client, avec mises à jour de DOM chirurgicales via WebSockets.
* **Ecto & PostgreSQL 16 :** Persistance relationnelle avec contraintes d'intégrité, transactions et schémas imbriqués (`cast_assoc`).
* **Tailwind CSS v4 & DaisyUI :** Design moderne, réactif et élégant avec gestion des thèmes sombre et clair (*dark/light mode*).
* **Phoenix PubSub & Presence :** Diffusion temps réel des états de jeu et comptage instantané des utilisateurs connectés.

### Modélisation OTP du moteur de jeu (`lib/quizir/games/`)
- Chaque partie active est incarnée par son propre processus `GenServer` sous supervision dynamique (`DynamicSupervisor`).
- Enregistrement par identifiant via `Registry` pour un routage sans goulot d'étranglement.
- **Cycle de vie optimisé :** Arrêt et déchargement automatique de la mémoire vive après 60 secondes d'inactivité une fois la partie terminée ou abandonnée.

### Parseur Markdown autonome (`lib/quizir/legal/`)
- Les pages **Mentions Légales**, **CGU** et **RGPD** sont rédigées dans des fichiers Markdown indépendants dans `priv/legal/`.
- Un parseur natif en pur Elixir convertit dynamiquement le Markdown en HTML sémantique sécurisé et stylisé avec les classes de l'application, sans aucune dépendance externe superflue.

---

## Installation avec Docker

Quizir intègre une configuration Docker prête pour la production avec base de données PostgreSQL, persistance des volumes et possibilité de rechargement à chaud.

### Prérequis
* [Docker](https://docs.docker.com/get-docker/) (v20.10+)
* [Docker Compose](https://docs.docker.com/compose/) (v2.0+)

### 1. Cloner le projet et préparer l'environnement
```bash
git clone https://github.com/votre-compte/quizir.git
cd quizir

# Création du fichier d'environnement
cp .env.example .env
```

#### Génération de la clé secrète (SECRET_KEY_BASE)
La variable `SECRET_KEY_BASE` est indispensable en production pour signer et chiffrer les sessions et cookies de l'application. Elle doit comporter au moins 64 octets aléatoires.

Plusieurs méthodes pour la générer facilement :

- **Avec Elixir (si installé sur la machine) :**
  ```bash
  mix phx.gen.secret
  ```
- **Avec Docker (si Elixir n'est pas installé) :**
  ```bash
  docker run --rm elixir:1.20-slim elixir -e 'IO.puts(:crypto.strong_rand_bytes(64) |> Base.encode64())'
  ```
- **Avec OpenSSL (disponible nativement sur Linux / macOS) :**
  ```bash
  openssl rand -base64 64
  ```

Renseignez ensuite la chaîne obtenue dans votre fichier `.env` :
```env
SECRET_KEY_BASE=votre_cle_generee_ici
```

Vous pouvez également adapter les autres variables dans le fichier `.env` (domaine, configuration SMTP pour les emails, stockage S3, etc.).

#### Configuration du stockage S3 pour les images (Optionnel)
Quizir permet d'associer des images d'illustration aux quiz (carte de présentation) et aux questions. **L'upload des images est activé uniquement si une configuration S3 est définie via les variables d'environnement.** En l'absence de ces variables, le téléversement d'images reste complètement désactivé dans l'application et aucun fichier n'est stocké sur le serveur local.

Pour activer le téléversement d'images avec un service de stockage compatible S3 (Amazon S3, Cloudflare R2, MinIO, Scaleway, Wasabi, OVHcloud, etc.), configurez les variables d'environnement suivantes :

| Variable | Obligatoire | Description | Exemple / Valeur par défaut |
| :--- | :---: | :--- | :--- |
| `S3_BUCKET` *(ou `AWS_S3_BUCKET`)* | Oui | Nom du bucket S3 | `quizir-media` |
| `S3_ACCESS_KEY_ID` *(ou `AWS_ACCESS_KEY_ID`)* | Oui | Identifiant de la clé d'accès | `AKIAIOSFODNN7EXAMPLE` |
| `S3_SECRET_ACCESS_KEY` *(ou `AWS_SECRET_ACCESS_KEY`)* | Oui | Clé secrète associée | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `S3_REGION` *(ou `AWS_REGION`)* | Non | Région géographique du bucket | `eu-west-3` *(défaut : `us-east-1`)* |
| `S3_ENDPOINT` *(ou `AWS_ENDPOINT_URL_S3`)* | Non | Endpoint S3 personnalisé (nécessaire pour MinIO, R2, Scaleway, etc.) | `https://s3.fr-par.scw.cloud` |
| `S3_PUBLIC_URL` | Non | URL publique de distribution (CDN ou domaine personnalisé) | `https://cdn.quizir.app` |

### 2. Démarrer l'application
Lancez l'ensemble des services (base de données et application Phoenix) en arrière-plan :

```bash
docker compose up --build -d
```

> **Note :** Si vous utilisez l'ancienne commande Docker Compose, tapez `docker compose up --build -d`.

### 3. Accéder à Quizir
Ouvrez votre navigateur sur :
**[http://localhost:4000](http://localhost:4000)**

* Lors de votre première visite, l'application détectera qu'aucun compte n'existe et vous invitera à **créer le premier compte administrateur**.
* Les migrations de base de données et la compilation des assets statiques sont exécutées automatiquement lors du démarrage du conteneur.

### 4. Commandes utiles Docker

| Action | Commande |
| :--- | :--- |
| **Suivre les logs applicatifs** | `docker compose logs -f app` |
| **Suivre les logs de la base de données** | `docker compose logs -f db` |
| **Déploiement à chaud (*Hot-reload*)** | `docker compose exec app deploy` |
| **Recharger sans interruption via signal** | `docker kill -s HUP $(docker compose ps -q app)` |
| **Ouvrir une console Elixir interactive** | `docker compose exec app iex --sname debug --remsh quizir@$(docker compose exec app hostname)` |
| **Arrêter les conteneurs** | `docker compose down` |
| **Arrêter et supprimer les volumes de données** | `docker compose down -v` |

---

## Démarrage en développement local

Si vous préférez exécuter l'application nativement sur votre machine hôte :

### Prérequis
* **Elixir** : version 1.17 ou 1.18+
* **Erlang/OTP** : version 27+
* **PostgreSQL** : version 14+ en local (port 5432)

### 1. Démarrer PostgreSQL (optionnel avec compose.yaml)
Si vous ne souhaitez pas installer PostgreSQL localement :
```bash
docker compose -f compose.yaml up -d
```

### 2. Installer les dépendances et initialiser la base
```bash
# Configuration de l'environnement
cp .env.example .env

# Installation des dépendances Elixir et préparation de la base
mix setup
```

La commande `mix setup` exécute successivement :
1. `mix deps.get` (téléchargement des dépendances)
2. `mix ecto.setup` (création de la base, migrations et exécution des seeds)
3. `mix assets.setup` et `mix assets.build` (compilation Tailwind et bundling JS)

### 3. Lancer le serveur Phoenix
```bash
mix phx.server
```
Ou avec une session IEx interactive :
```bash
iex -S mix phx.server
```

Rendez-vous ensuite sur **[http://localhost:4000](http://localhost:4000)**.

---

## Tests et Qualité de code

Le projet dispose d'une suite de tests complète (unitaires, contextes, LiveViews multijoueur, authentification et intégration) :

```bash
# Exécuter tous les tests
mix test

# Exécuter les vérifications de qualité complètes (compilation stricte, formatage, tests)
mix precommit
```

Un pipeline d'intégration continue **GitHub Actions** (`.github/workflows/ci.yml`) valide automatiquement la compilation sans warning, le formatage et l'ensemble des tests sur les branches `main` et `develop` ainsi que sur chaque Pull Request.

---

## Protection des données & Engagements légaux

Dans le respect le plus strict des principes du **RGPD** et de la déontologie du développement logiciel :

* **Aucune transmission à des tiers :** Aucune donnée personnelle, statistique de partie ou adresse IP n'est partagée, vendue ou transmise à un tiers ou une régie publicitaire.
* **Zéro traqueur :** Aucun script de suivi tiers (Google Analytics, Meta Pixel, etc.) n'est intégré.
* **Cookies techniques stricts :** Seuls les cookies de session chiffrés indispensables au fonctionnement de Phoenix LiveView sont utilisés.
* **Consultation libre :** Les pages [Mentions Légales](/mentions-legales), [CGU](/cgu) et [RGPD](/rgpd) sont consultables en pied de page de l'application à tout moment.

---

## Licence

Ce projet est distribué sous licence MIT. Consultez le fichier [LICENSE](LICENSE) pour plus de détails.
