# ADR-006 : Externalisation et Centralisation de la Configuration - Spring Cloud Config

* **Statut** : Accepté
* **Date** : 2026-10-25
* **Auteurs** : Mouhamadou Abdoulaye SOW, Médoune DIOP, Abdou Salam MBOUP, Matar Faly SAMBE (DIC2 EPT)
* **Contexte Technique** : Gestion des configurations d'environnements (12-Factor App)

---

## 1. Contexte et Problématique

Avec plusieurs microservices déployés en conteneurs (découverte, passerelle, catalogue, utilisateurs, IA, notifications), maintenir des fichiers `application.properties` ou `application.yml` dispersés et recompilés avec le code source pose de sérieux problèmes :
- Risque de fuite de mots de passe de bases de données dans les dépôts de code.
- Nécessité de recompiler un JAR pour simplement changer l'URL d'un service ou une variable d'environnement.
- Violation du principe III du manifeste *The Twelve-Factor App* (« Store config in the environment »).

---

## 2. Alternatives Envisagées

### Option A : Variables d'environnement injectées manuellement par conteneur
* **Avantages** : Aucun service supplémentaire requis, support natif par Docker.
* **Inconvénients** : Définition répétitive et sujette aux erreurs dans les fichiers compose, pas de traçabilité des modifications, pas de rechargement à chaud (Hot Reload).

### Option B : HashiCorp Consul KV
* **Avantages** : Support natif clé-valeur et découverte de service unifiée.
* **Inconvénients** : Ajout d'une stack technologique Go externe au monde Spring Boot.

### Option C : Spring Cloud Config Server + Git Repo (Solution Retenue)
* **Avantages** :
  - Parfaite synergie avec l'écosystème Spring Boot / Spring Cloud.
  - Gestion versionnée de la configuration dans un dépôt de configuration dédié (`config-repo/`).
  - Prise en charge des profils (`dev`, `staging`, `prod`) avec résolution hiérarchique.
  - Chiffrement symétrique ou asymétrique possible des valeurs sensibles (secrets).
* **Inconvénients** : Dépendance au démarrage : les microservices doivent attendre la disponibilité du serveur de configuration.

---

## 3. Décision

Nous déployons **Spring Cloud Config Server** (sur le port 8888) adossé au dossier local versionné `config-repo/` :
- Chaque microservice ne conserve en local qu'un fichier minimal `bootstrap.yml` ou `application.yml` pointant vers l'URL du Config Server.
- Au démarrage, chaque service télécharge sa configuration propre (`course-service.yml`, `user-service.yml`, etc.) ainsi que les propriétés globales partagées (`application.yml`).
- L'ordre de démarrage dans `docker-compose.yml` garantit que `config-server` et `discovery-server` sont prêts avant les services applicatifs métier grâce aux clauses `depends_on` avec `condition: service_healthy`.

---

## 4. Conséquences

### Positives
* Séparation stricte entre le binaire applicatif (immuable) et la configuration par environnement.
* Auditabilité totale : chaque modification de paramètre est tracée par un commit Git.
* Simplification drastique de la maintenance multi-environnements (local, staging, production AWS).

### Négatives & Mesures d'atténuation
* *Délai de démarrage initial* : Géré par des scripts d'attente d'initialisation (`wait-for-it` / healthcheck Docker) évitant les crashs en boucle au boot.
