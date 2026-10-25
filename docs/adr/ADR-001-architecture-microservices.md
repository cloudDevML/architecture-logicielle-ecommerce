# ADR-001 : Choix du style architectural - Microservices vs Monolithe Modulaire

* **Statut** : Accepté
* **Date** : 2026-10-25
* **Auteurs** : Mouhamadou Abdoulaye SOW, Médoune DIOP, Abdou Salam MBOUP, Matar Faly SAMBE (DIC2 EPT)
* **Contexte Technique** : Plateforme E-Commerce de formations & certifications numériques (EduMarket)

---

## 1. Contexte et Problématique

La plateforme EduMarket a pour vocation de commercialiser des formations numériques spécialisées, des parcours certifiants et des modules interactifs à destination de développeurs, étudiants et professionnels. Le système doit concilier des exigences métiers variées :
- Gestion des comptes, profils et rôles multiples (Clients/Apprenants, Formateurs/Vendeurs, Administrateurs).
- Catalogue de formations volumineux avec recherche textuelle et sémantique.
- Parcours d'achat, de commande et d'inscription immédiate avec facturation.
- Recommandation intelligente basée sur l'IA (LLM, embeddings vectoriels, détection des lacunes).
- Notification en temps réel et messagerie collaborative.

Face à ces besoins, nous devions trancher entre deux approches architecturales fondamentales abordées durant le séminaire :
1. Un **Monolithe Modulaire** (ex: une seule application Spring Boot packagée sous forme d'artefact unique).
2. Une **Architecture en Microservices** (services autonomes, découplés, déployables indépendamment).

---

## 2. Alternatives Envisagées

### Option A : Monolithe Modulaire
* **Avantages** : Simplicité de développement initial, déploiement unique, pas de complexité réseau inter-services ni de transactions distribuées.
* **Inconvénients** : Dépendance technologique unique, couplage fort des composants, risque d'effet de bord lors des montées de version, mise à l'échelle globale coûteuse (on doit scaler tout le monolithe pour un seul sous-système sollicité), cycles de release lourds.

### Option B : Microservices (Solution Retenue)
* **Avantages** :
  - Découpage strict par domaine métier (DDD - Domain-Driven Design / Bounded Contexts).
  - Évolutivité indépendante (ex: scaler le service Catalogue ou l'API Gateway indépendamment du service de Réunion).
  - Résilience accrue : la défaillance d'un service non critique (ex: service IA ou messagerie) n'empêche pas l'utilisateur de consulter le catalogue ou d'acheter une formation.
  - Déploiement et intégration continue granulaires.
* **Inconvénients** : Complexité opérationnelle accrue (découverte de services, traçabilité distribuée, gestion des configurations, résilience réseau).

---

## 3. Décision

Nous retenons l'**Architecture en Microservices** pour concevoir la plateforme EduMarket.
Le système est découpé selon les domaines métiers suivants :
1. **API Gateway** : Point d'accès unique, routage dynamique, contrôle de sécurité JWT et rate limiting.
2. **Discovery Server (Netflix Eureka)** : Enregistrement et localisation dynamique des instances de services.
3. **Config Server** : Centralisation et distribution dynamique des configurations par environnement.
4. **User Service** : Gestion des comptes, des rôles et des données de profil.
5. **Course Service (Catalogue & Commandes)** : Gestion des formations, fiches produits, modules, pricing, commandes et souscriptions.
6. **AI Service** : Recommandations de formations sémantiques basées sur RAG et modèles de langage.
7. **Announcement Service** : Notifications événementielles et messagerie inter-utilisateurs.

---

## 4. Conséquences

### Positives
* Respect strict des principes de haute cohésion et de faible couplage.
* Capacité à industrialiser chaque composant via des pipelines CI/CD distincts.
* Déploiement conteneurisé cohérent et reproductible avec Docker.

### Négatives & Mesures d'atténuation
* *Complexité de la communication inter-services* : Atténuée par l'utilisation conjointe de Spring Cloud Gateway, OpenFeign pour le synchrone et Apache Kafka pour l'asynchrone.
* *Surcoût mémoire à l'exécution locale* : Atténué par un profil `docker-compose.yml` optimisé avec limites de mémoire (cgroup memory limits) sur chaque conteneur.
