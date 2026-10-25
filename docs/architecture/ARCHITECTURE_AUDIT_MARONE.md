# Grille d'Audit Architectural & Conformité — Séminaire M. MARONE

**Projet** : EduMarket — Plateforme E-Commerce de Formations Numériques  
**Auteur de l'Audit** : Abdou Salam MBOUP (`salamboup2016@gmail.com` / `@AbdouGreen`)  
**Rôle** : Lead Architecte Logiciel, Modélisation, Documentation & CI/CD  
**Date d'Évaluation** : 25 Octobre 2026  

---

## Synthèse Générale de Conformité

Cet audit technique évalue point par point la conformité de l'architecture logicielle d'**EduMarket** par rapport aux enseignements, cas pratiques et patterns dispensés lors du séminaire d'**Architecture Logicielle Moderne** (Promotion DIC2 2026 — École Polytechnique de Thiès).

| Axe du Séminaire | Thèmes Clés Enseignés par M. MARONE | Statut EduMarket | Justification & Artefact |
| :--- | :--- | :---: | :--- |
| **Module 1 : Comprendre & Choisir** | Fondamentaux, Styles (Monolithe vs Microservices), Matrice de décision, Compromis | ✅ Validé | ADR-001, Matrice de décision à 6 critères, justification contexte e-commerce. |
| **Module 2 : Concevoir** | DDD (Bounded Contexts, Ubiquitous Language, Aggregate), Hexagonal/Clean, Patterns, ADR | ✅ Validé | Bounded Contexts délimités, Ports & Adaptateurs `course-service`, 8 ADRs Nygard. |
| **Module 3 : Industrialiser** | CI/CD, DevSecOps, Docker Multi-stage, 12-Factor Apps, Observabilité (3 piliers) | ✅ Validé | Pipeline `.gitlab-ci.yml`, configs Git-backed, Actuator/Micrometer, traces logs. |
| **Module 4 : Distribuer & Gouverner** | Théorème CAP (CP vs AP), Scalabilité Black Friday, Strangler Fig Pattern, Gouvernance | ✅ Validé | Arbitrage CAP formalisé (CP Commande vs AP Catalogue), migration progressive. |

---

## 1. Audit du Module 1 : Comprendre & Choisir

### 1.1 Principe Fondamental : « Architecture = Décisions + Compromis »
* **Enseignement** : Il n'existe pas d'architecture universelle. Le monolithe n'est pas mauvais, le microservice n'est pas supérieur par défaut. La distribution a un coût opérationnel.
* **Application EduMarket** : L'équipe a documenté ce compromis dans **ADR-001** :
  - *Bénéfices recherchés* : Scalabilité indépendante du catalogue (lecture intensive) et des commandes (écriture transactionnelle), autonomie de déploiement de l'assistant IA.
  - *Coûts acceptés et maîtrisés* : Complexité réseau inter-services, latence IPC compensée par Kafka asynchrone, industrialisation Docker Compose.

### 1.2 Matrice de Décision Confrontée au Contexte
La grille comparative de la diapositive 22 du cours a été scrupuleusement appliquée :
* **Rapidité initiale** : Monolithe modulaire (⭐⭐⭐) vs Microservices (⭐⭐).
* **Scalabilité ciblée** : Monolithe (⭐) vs Microservices (⭐⭐⭐).
* **Indépendance d'évolution** : Monolithe (⭐) vs Microservices (⭐⭐⭐).
* **Résultat de l'arbitrage** : Le profil e-commerce à forte composante IA et mobile justifie l'architecture distribuée.

---

## 2. Audit du Module 2 : Concevoir

### 2.1 Domain-Driven Design (DDD)
* **DDD Stratégique** :
  - *Catalogue Context* : Entités `Course`, `CModule`, métadonnées, durée, syllabus.
  - *Commande Context* : Entité `Order`, calcul de panier, transition d'état atomique `PENDING` $\rightarrow$ `PAID`.
  - *Identité Context* : `user-service`, authentification stateless OAuth2/JWT.
  - *Notification Context* : `announcement-service`, alertes temps réel WebSockets.
* **Langage Ubiquitaire (Ubiquitous Language)** : Le mot « Cours » désigne un programme pédagogique complet dans le contexte d'apprentissage, et une référence vendable avec prix unitaire et devise (`Price / Currency`) dans le contexte Commande.
* **DDD Tactique** :
  - `Order` est l'Agrégat Racine garantissant l'invariant (montant $> 0$, client non vide, statut valide).
  - Émission de l'événement de domaine `OrderConfirmedEvent` vers le bus Kafka.

### 2.2 Clean Architecture & Architecture Hexagonale
Dans `course-service` :
* **Cœur Métier (Domaine)** : `com.lms.course.ecommerce.Order` et `OrderRequest` isolés de toute dépendance Spring ou SQL.
* **Port Entrant (Driving)** : Interface `OrderService` définissant les cas d'usage `createOrder()` et `confirmPayment()`.
* **Adaptateur Entrant** : `OrderController` traduisant les requêtes HTTP/JSON en appels de port.
* **Port Sortant (Driven)** : Interface `OrderRepository` et publisher d'événements.
* **Adaptateurs Sortants** : Implémentation Spring Data JPA (PostgreSQL) et `KafkaTemplate`.
* **Règle de Dépendance** : Respectée à 100%, le domaine ne référence aucun framework externe.

### 2.3 Patterns de Résilience & Typologie des Erreurs (Slide 43)
* **Erreur Métier** (ex: formation inexistante, commande déjà payée) $\rightarrow$ Rejet immédiat avec code HTTP `400 / 404 / 409`, aucun retry.
* **Erreur Technique** (ex: timeout base PostgreSQL) $\rightarrow$ Code `500 / 503`, retry avec backoff exponentiel.
* **Erreur d'Intégration** (ex: message Kafka corrompu) $\rightarrow$ Routage vers Dead Letter Queue (DLQ).

---

## 3. Audit du Module 3 : Industrialiser

### 3.1 Pipeline CI/CD DevSecOps (Slide 57)
Le pipeline automatisé implémente la séquence préconisée par M. MARONE :
$$\text{LINT} \longrightarrow \text{SECURITY} \longrightarrow \text{TEST} \longrightarrow \text{BUILD} \longrightarrow \text{DOCKER PACKAGE} \longrightarrow \text{DEPLOY}$$
* Linting syntaxique Maven et validation TypeScript.
* Tests unitaires automatisés (`OrderServiceTest`, `OrderControllerTest` : 7/7 réussis).
* Multi-stage build Docker garantissant des images légères sans outils de build en production.

### 3.2 Principes Cloud Native (12-Factor Apps)
* **Facteur III (Config)** : Externalisée dans `config-repo/` et distribuée via Spring Cloud Config.
* **Facteur VI (Stateless)** : Microservices sans état en mémoire vive, sessions portées par des tokens JWT cryptographiques.
* **Facteur XI (Logs)** : Émission sur `stdout` collectée par Docker et les outils de supervision.

### 3.3 Observabilité — Les 3 Piliers (Slide 63)
* **Logs** : Format JSON horodaté intégrant le `traceId` de bout en bout.
* **Metrics** : Endpoints Actuator (`/actuator/health`, `/actuator/metrics`, `/actuator/prometheus`).
* **Traces** : Corrélation des requêtes traversant l'API Gateway jusqu'à `course-service` et Kafka.

---

## 4. Audit du Module 4 : Distribuer & Gouverner

### 4.1 Théorème CAP — Cas Pratique E-Commerce (Slide 68)
* **Service Commande & Paiement (Choix CP)** : Lors d'une partition réseau, priorité absolue à la cohérence. Aucune commande n'est validée en mode dégradé pour interdire les doubles débits financiers.
* **Service Catalogue (Choix AP)** : Priorité à la disponibilité. Les fiches de cours continuent d'être servies depuis le cache local pour ne jamais bloquer la navigation des utilisateurs.

### 4.2 Scalabilité Ciblée (Slide 71)
* « On ne scale pas le système : on scale le goulot d'étranglement ».
* L'API Gateway et le catalogue sont réplicables horizontalement (*scale-out*), tandis que la base de données bénéficie d'une isolation stricte (*Database-per-Service*).

### 4.3 Stratégie de Migration : Strangler Fig Pattern (Slide 75)
* L'extraction du module Commande a suivi la méthode d'étranglement progressif :
  1. *Identifier* le domaine commande.
  2. *Router* les URLs `/api/orders/**` via l'API Gateway.
  3. *Migrer* le service en parallèle.
  4. *Bascule* 100% sans interruption de service.

---

## Conclusion de l'Audit

L'architecture d'**EduMarket** répond de manière rigoureuse, justifiée et documentée à l'intégralité des standards académiques et industriels exigés pour le rendu final du séminaire.
