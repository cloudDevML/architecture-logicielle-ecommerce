# ADR-002 : Stratégie de persistance - Database-per-Service

* **Statut** : Accepté
* **Date** : 2026-10-25
* **Auteurs** : Mouhamadou Abdoulaye SOW, Médoune DIOP, Abdou Salam MBOUP, Matar Faly SAMBE (DIC2 EPT)
* **Contexte Technique** : Persistance des microservices

---

## 1. Contexte et Problématique

Dans une architecture microservices, le couplage par la base de données (Shared Database anti-pattern) constitue le risque majeur de recréer un « monolithe distribué ». Si plusieurs microservices lisent et écrivent dans les mêmes tables ou partagent un même schéma, toute modification de modèle de données impose des déploiements synchronisés et brise l'autonomie des services.

La question était de choisir la stratégie de persistance la plus adaptée pour EduMarket entre :
1. Une **Base de données partagée unique (Shared Database)**.
2. Une **Base de données isolée par service (Database-per-Service)**.

---

## 2. Alternatives Envisagées

### Option A : Shared Database (Base unique partagée)
* **Avantages** : Requêtes jointures SQL directes faciles entre domaines (ex: joindre la table Utilisateur avec la table Commandes et Cours), transactions ACID distribuées immédiates.
* **Inconvénients** : Violation du principe d'encapsulation DDD, conflits de verrouillage (locks), risque de corruption de données partagées, blocage des évolutions de schémas.

### Option B : Database-per-Service (Solution Retenue)
* **Avantages** :
  - Découplage strict des schémas : chaque service est le garant unique de son modèle de données.
  - Possibilité de persistance polyglotte (ex: PostgreSQL relationnel pour les commandes/utilisateurs, pgvector pour les embeddings IA).
  - Évolutivité indépendante sans impact sur les services tiers.
* **Inconvénients** : Impossibilité d'effectuer des jointures SQL inter-bases, nécessité d'orchestrer la cohérence à terme (Eventual Consistency).

---

## 3. Décision

Nous adoptons le pattern **Database-per-Service**. 
Dans notre architecture conteneurisée :
- Une instance PostgreSQL commune héberge des bases logiques distinctes strictement séparées :
  - `user_db` pour le microservice Utilisateurs.
  - `course_db` pour le microservice Catalogue et Commandes.
  - `ai_db` avec l'extension `pgvector` pour le microservice IA et RAG.
  - `announcement_db` pour les notifications et alertes.
- Aucun microservice n'a le droit de se connecter à la base de données d'un autre microservice. Les échanges de données se font exclusivement via des contrats d'API REST ou des messages Kafka.
- L'initialisation automatique des différentes bases est assurée au démarrage via le script `postgres-init/init.sql`.

---

## 4. Conséquences

### Positives
* Indépendance totale des migrations de schéma JPA/Hibernate par service.
* Intégrité des données protégée au niveau applicatif.
* Modularité préservée pour une migration future vers des bases physiquement hébergées sur des clusters distincts (ex: AWS RDS Aurora).

### Négatives & Mesures d'atténuation
* *Jointures impossibles en base* : Résolues par dénormalisation ciblée (stockage de l'identifiant et nom d'utilisateur dans la commande) ou requêtes d'enrichissement via REST/Feign.
