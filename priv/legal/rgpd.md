# Politique de Confidentialité & RGPD

Dernière mise à jour : 22 septembre 2026

## 1. Engagement de transparence et cadre légal

La présente Politique de Confidentialité s'inscrit dans le cadre du **Règlement Général sur la Protection des Données (RGPD - Règlement UE 2016/679)** ainsi que de la loi Informatique et Libertés.

La plateforme **Quizir** a pour objet unique la **démonstration technique des compétences de ses développeurs** dans la conception d'architectures web modernes en temps réel (Elixir, Phoenix LiveView, WebSockets, OTP).

Ce projet étant un démonstrateur technologique et une vitrine d'ingénierie à but non lucratif, la sobriété numérique, le respect de la vie privée et la minimisation de la collecte des données sont appliqués par défaut (*privacy by design*).

---

## 2. Règle d'or : Aucune transmission de données à des tiers

Nous affirmons avec force et clarté notre engagement :

> **Aucune donnée personnelle, identifiant, statistique de jeu, adresse IP ou information de navigation n'est vendue, louée, cédée, partagée ou transmise à un tiers, sous quelque forme et à quelque titre que ce soit.**

- **Zéro régie publicitaire :** Nous n'intégrons aucun réseau d'annonces, régie d'affiliation ou script marketing.
- **Zéro traqueur externe :** Nous n'utilisons aucun outil de tracking ou d'analyse comportementale externe (type Google Analytics, Meta Pixel, etc.).
- **Zéro sous-traitant commercial :** L'intégralité du traitement applicatif s'exécute directement sur l'infrastructure d'hébergement du projet.

---

## 3. Données collectées et minimisation

Conformément au principe de minimisation (article 5.1.c du RGPD), seules les données strictement nécessaires au bon déroulement technique des fonctionnalités de jeu et d'administration sont traitées :

### 3.1. Pour les joueurs participants (mode invité / guest)
- **Pseudonyme choisi :** Utilisé uniquement pour identifier le joueur dans la salle d'attente et sur le tableau des scores de la partie en cours.
- **Réponses fournies et temps de réaction :** Utilisés pour le calcul du score en temps réel par les processus OTP de la partie.
- Ces données sont temporaires et disparaissent lors de l'archivage ou du nettoyage des sessions de jeu.

### 3.2. Pour les organisateurs et créateurs de quiz (comptes enregistrés)
- **Nom d'utilisateur / Identifiant :** Requis pour s'authentifier.
- **Mot de passe :** Immédiatement haché de manière irréversible à l'aide de l'algorithme cryptographique robuste **PBKDF2**. Le mot de passe en clair n'est jamais stocké ni accessible.
- **Adresse email (si renseignée) :** Utilisée exclusivement pour l'authentification et les éventuelles procédures de récupération d'accès.
- **Quiz créés :** Titres, questions, réponses et paramètres associés nécessaires à la diffusion des parties.

---

## 4. Politique relative aux cookies et stockage local

La plateforme utilise exclusivement des technologies de session indispensables :

- **Cookies techniques de session :** Ces cookies chiffrés et signés cryptographiquement permettent de maintenir la connexion sécurisée à Phoenix LiveView et de retenir l'état de navigation.
- **Absence de traceurs publicitaires :** Conformément aux recommandations de la CNIL et aux directives européennes ePrivacy, ces témoins étant strictement nécessaires à la fourniture du service expressément demandé par l'utilisateur, ils ne nécessitent pas de bandeau de consentement publicitaire intrusif.

---

## 5. Durée de conservation des données

- **Données de parties en mémoire :** Les processus de jeu sont automatiquement arrêtés et déchargés de la mémoire vive OTP après la fin des parties ou en cas d'inactivité prolongée (60 secondes après l'abandon ou la conclusion d'une partie).
- **Comptes utilisateurs et quiz :** Conservés pour la durée de vie du démonstrateur technique ou jusqu'à la demande de suppression de l'utilisateur. En tant qu'environnement de démonstration, des purges ponctuelles de base de données de test peuvent également intervenir.

---

## 6. Sécurité des traitements

Plusieurs mesures techniques et organisationnelles sont mises en œuvre :
- **Chiffrement des communications :** Tous les flux de navigation et sockets WebSockets transitent via des protocoles sécurisés (HTTPS / WSS - TLS).
- **Hachage cryptographique :** Protection des identifiants d'accès par PBKDF2 avec sel unique.
- **Isolation des processus OTP :** Chaque partie s'exécute dans des processus BEAM isolés, garantissant une étanchéité forte entre les différentes salles de jeu.

---

## 7. Vos droits relatifs à vos données

Conformément aux articles 15 à 22 du RGPD, vous disposez des droits suivants concernant vos données à caractère personnel :

- **Droit d'accès :** Obtenir la confirmation que des données vous concernant sont traitées et en obtenir une copie.
- **Droit de rectification :** Demander la modification de données inexactes ou incomplètes.
- **Droit à l'effacement (« droit à l'oubli ») :** Demander la suppression définitive de votre compte et des quiz associés.
- **Droit d'opposition et de limitation du traitement.**

Pour exercer l'un de ces droits, vous pouvez contacter les développeurs à l'adresse **contact@quizir.local** ou via l'espace de gestion du dépôt de code. Votre demande sera traitée dans les meilleurs délais.
