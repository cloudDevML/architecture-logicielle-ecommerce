# EduMarket — Plateforme E-Commerce de Formations & Certifications Numériques

[![CI/CD Pipeline](https://github.com/cloudDevML/architecture-logicielle-ecommerce/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/cloudDevML/architecture-logicielle-ecommerce/actions)
[![Architecture](https://img.shields.io/badge/Architecture-Microservices%20Spring%20Cloud-blue.svg)](#architecture-globale)
[![Module](https://img.shields.io/badge/Module-Architecture%20Logicielle-emerald.svg)](#contexte-académique)
[![Promotion](https://img.shields.io/badge/EPT-DIC2%20Promotion%202026-purple.svg)](#auteurs)

Projet transversal conçu et réalisé dans le cadre du module d'**Architecture Logicielle** .  
Ce dépôt matérialise la démarche complète vue en séminaire :  
**Besoin métier → Analyse → Architecture → Conception → Implémentation → Documentation → CI/CD**.

---

## Sommaire

1. [Contexte Métier & Périmètre du MVP](#1-contexte-métier--périmètre-du-mvp)
2. [Architecture Globale & Choix Techniques](#2-architecture-globale--choix-techniques)
3. [Documentation d'Architecture & ADRs](#3-documentation-darchitecture--adrs)
4. [Démarrage Rapide (Docker Compose)](#4-démarrage-rapide-docker-compose)
5. [Industrialisation & CI/CD](#5-industrialisation--cicd)
6. [Structure du Projet](#6-structure-du-projet)
7. [Livrables & Rapport de Synthèse](#7-livrables--rapport-de-synthèse)
8. [Auteurs](#8-auteurs)

---

## 1. Contexte Métier & Périmètre du MVP

### Le Besoin Métier
Le projet **EduMarket** est une plateforme e-commerce spécialisée dans la vente de **formations numériques à la demande, modules de spécialisation certifiants et parcours d'ingénierie informatique** (Cloud, DevOps, Microservices, IA).

### Les Acteurs (Personas)
* **Apprenant / Client (B2C)** : Navigue sur le catalogue, filtre par domaine/prix, consulte la fiche formation (syllabus, avis, tarifs), valide son panier, effectue le règlement et accède instantanément à sa bibliothèque de formation avec suivi d'avancement et certifications.
* **Formateur / Vendeur (Merchant)** : Publie de nouveaux modules de cours, fixe les tarifs, charge les supports multimédias (vidéos, fiches PDF, quiz d'évaluation) et consulte le volume d'inscriptions et de ventes.
* **Administrateur** : Supervise les utilisateurs, modère le catalogue, suit les flux de transactions et supervise la santé des microservices.

### Fonctionnalités Clés du MVP
- **Authentification & Gestion des Rôles** (Clients, Vendeurs, Admins avec JWT).
- **Catalogue & Fiches Formations** (Recherche, filtrage, tarification unitaire, prérequis).
- **Panier & Gestion des Commandes** (Création de commande `PENDING`, validation et simulation de paiement `PAID`).
- **Moteur de Recommandation IA** (Orientation personnalisée vers les cours adaptés aux lacunes de l'acheteur via RAG et embeddings vectoriels).
- **Espace Apprenant** (Accès aux contenus achetés, quiz interactifs, certificats de complétion).
- **Notifications Temps Réel** (Confirmation de commande et alertes via WebSockets et Kafka).

---

## 2. Architecture Globale & Choix Techniques

Le système repose sur une **Architecture Microservices événementielle (Event-Driven Architecture)** :

```
                        ┌────────────────────────────────────────┐
                        │      Client Web React (TypeScript)     │
                        └───────────────────┬────────────────────┘
                                            │ HTTP / REST
                                            ▼
                        ┌────────────────────────────────────────┐
                        │    api-gateway (Spring Cloud Gateway)   │ (Port 8080)
                        └─────────┬───────────────────┬──────────┘
                                  │                   │
                  ┌───────────────┴────────┐ ┌────────┴──────────────┐
                  ▼                        ▼ ▼                       ▼
        ┌──────────────────┐    ┌────────────────────┐    ┌─────────────────────┐
        │  discovery-server│    │    user-service    │    │    course-service   │
        │ (Netflix Eureka) │    │  (Port 8081 - Auth)│    │(Port 8082 - Catalog │
        └──────────────────┘    └─────────┬──────────┘    │      & Orders)      │
                                          │               └──────────┬──────────┘
                                          │                          │
                                          ▼                          ▼
                                   [ user_db ]                [ course_db ]
                                                                     │
                                      ┌──────────────────────────────┴──────────┐
                                      │ Kafka Broker (order.events topic)       │
                                      └──────────────┬──────────────────────────┘
                                                     ▼
                                          ┌──────────────────────┐
                                          │ announcement-service │ (Notifications)
                                          └──────────────────────┘
```

* **API Gateway** : Spring Cloud Gateway (Port `8080`), sécurisation JWT et routage dynamique.
* **Service Discovery** : Netflix Eureka (Port `8761`).
* **Configuration Centralisée** : Spring Cloud Config Server (Port `8888`).
* **Microservices Métiers** : Spring Boot 3.3.x (Java 21), Spring Data JPA, Hibernate.
* **Persistance Polyglotte** : PostgreSQL 16 avec pattern *Database-per-Service* + `pgvector` pour l'IA.
* **Asynchronisme & Événements** : Apache Kafka pour le découplage des commandes et notifications.
* **Frontend** : React 18 SPA, TypeScript, TailwindCSS / Nginx Alpine.
* **Stockage Objets** : MinIO (compatible AWS S3) pour les médias pédagogiques.

---

## 3. Documentation d'Architecture & ADRs

Toutes les décisions et représentations architecturales sont documentées de manière exhaustive :

* 📁 **[Dossier des Décisions d'Architecture (ADRs)](docs/adr/README.md)** :
  * [ADR-001 : Microservices vs Monolithe Modulaire](docs/adr/ADR-001-architecture-microservices.md)
  * [ADR-002 : Stratégie Database-per-Service](docs/adr/ADR-002-database-per-service.md)
  * [ADR-003 : API Gateway & Service Discovery](docs/adr/ADR-003-api-gateway-service-discovery.md)
  * [ADR-004 : Communication Asynchrone avec Apache Kafka](docs/adr/ADR-004-communication-asynchrone-kafka.md)
  * [ADR-005 : Sécurité Décentralisée par JWT & Keycloak](docs/adr/ADR-005-authentification-jwt-keycloak.md)
  * [ADR-006 : Configuration Centralisée avec Spring Cloud Config](docs/adr/ADR-006-configuration-centralisee-spring-cloud-config.md)
  * [ADR-007 : Conteneurisation & Orchestration Docker](docs/adr/ADR-007-conteneurisation-docker-compose.md)
  * [ADR-008 : Stratégie CI/CD Multi-Plateforme](docs/adr/ADR-008-pipeline-ci-cd-automatise.md)

* 📁 **[Diagrammes d'Architecture (Modèle C4)](docs/architecture/README.md)** :
  * [C4 Niveau 1 : Diagramme de Contexte Système](docs/architecture/01_c4_system_context.md)
  * [C4 Niveau 2 : Diagramme des Conteneurs](docs/architecture/02_c4_container_diagram.md)
  * [C4 Niveau 3 : Diagramme des Composants (Catalog & Orders)](docs/architecture/03_c4_component_diagram.md)
  * [Diagramme de Séquence : Parcours d'Achat & Inscription](docs/architecture/04_sequence_order_flow.md)
  * [Topologie de Déploiement : Docker & Cloud EC2](docs/architecture/05_deployment_topology.md)

---

## 4. Démarrage Rapide (Docker Compose)

### Prérequis
* Docker Engine 24+ & Docker Compose v2+
* 4 Go de RAM alloués à Docker

### Lancement en une commande

```bash
# 1. Se positionner dans le dossier des microservices
cd lms-microservices

# 2. Configurer les variables d'environnement (copie du template pré-configuré)
cp .env.example .env

# 3. Démarrer l'ensemble des conteneurs
docker compose up -d
```

### URLs d'Accès aux Services
| Service | URL locale | Description |
| :--- | :--- | :--- |
| **Storefront Web (Frontend)** | `http://localhost` | Interface e-commerce (Catalogue, Panier, Profil) |
| **API Gateway** | `http://localhost:8080` | Point d'entrée unique de toutes les requêtes API |
| **Eureka Discovery Dashboard**| `http://localhost:8761` | Console d'observation des microservices enregistrés |
| **Documentation Swagger / OpenAPI**| `http://localhost:8080/swagger-ui.html` | Spécification interactive des endpoints |
| **Console MinIO S3** | `http://localhost:9001` | Exploration des médias et supports de formation |

---

## 5. Industrialisation & CI/CD

Le projet intègre un pipeline CI/CD automatisé conforme aux exigences du séminaire :
* **GitLab CI** : Configuration officielle via [`.gitlab-ci.yml`](.gitlab-ci.yml).
* **GitHub Actions** : Workflow miroir via [`.github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml).

### Étapes du Pipeline
1. **Lint** : Vérification de la syntaxe et des dépendances Maven et TypeScript.
2. **Test** : Exécution automatique des tests unitaires (`OrderServiceTest`, `OrderControllerTest`, `App.test.tsx`).
3. **Build** : Compilation et packaging des JARs et du bundle frontend.
4. **Docker Package** : Validation de la cohérence de la topologie de conteneurs.
5. **Deploy** : Déploiement automatisé sur serveur Cloud de staging.

Les preuves réelles d'exécution et de validation sont consignées dans [docs/proofs/](docs/proofs/).

---

## 6. Structure du Projet

```
architecture_logicielle/
├── .github/workflows/          # Pipelines GitHub Actions
├── .gitlab-ci.yml              # Pipeline GitLab CI
├── docs/
│   ├── adr/                    # Registre des Décisions d'Architecture (ADR-001 à 008)
│   ├── architecture/           # Spécifications et diagrammes C4
│   └── proofs/                 # Preuves de compilation et d'exécution des tests
├── lms-frontend/               # Application React 18 SPA (TypeScript / Tailwind)
├── lms-microservices/          # Écosystème backend Spring Boot & Spring Cloud
│   ├── api-gateway/            # Passerelle de routage & sécurité
│   ├── discovery-server/       # Annuaire Eureka
│   ├── config-server/          # Serveur de configuration centralisé
│   ├── config-repo/            # Dépôt de configuration des services
│   ├── user-service/           # Microservice utilisateurs, profils & rôles
│   ├── course-service/         # Microservice catalogue, formations & commandes
│   ├── ai-service/             # Moteur de recommandation RAG & LLM
│   ├── announcement-service/   # Notifications & messagerie
│   ├── postgres-init/          # Script d'initialisation des bases de données
│   └── docker-compose.yml      # Orchestration de l'infrastructure complète
├── rapport/                    # Rapport synthétique d'Architecture (10 pages)
│   ├── RAPPORT_ARCHITECTURE_LOGICIELLE.md
│   └── RAPPORT_ARCHITECTURE_LOGICIELLE.pdf
└── README.md                   # Présentation du projet
```

---

## 7. Livrables & Rapport de Synthèse

Conformément aux consignes de rendu :
* **Dépôt Git** : Contient l'intégralité du code source, l'historique propre, les Dockerfiles, la CI/CD et la documentation.
* **Rapport de Synthèse (10 pages max)** : Disponible sous format Markdown et PDF prêt à imprimer :
  * 📄 **[Consulter le Rapport d'Architecture Logicielle (Markdown)](rapport/RAPPORT_ARCHITECTURE_LOGICIELLE.md)**
  * 📑 **[Télécharger le Rapport au format PDF (A4 imprimable)](rapport/RAPPORT_ARCHITECTURE_LOGICIELLE.pdf)**

Le rapport traite en profondeur des 4 axes imposés :
1. Démarche de conception (besoins, périmètre MVP, justifications, ADRs).
2. Architecture logicielle (modèle C4, composants, interactions, organisation du code).
3. MVP fonctionnel (parcours d'achat, catalogue, gestion des états).
4. Industrialisation et déploiement (Git, tests, CI/CD, preuves de build et guide d'installation).

---

## 8. Auteurs

* **Mouhamadou Abdoulaye SOW**
* **Médoune DIOP**
* **Abdou Salam MBOUP**
* **Matar Faly SAMBE**

*Élèves-Ingénieurs en Génie Informatique & Télécommunications — DIC2 *  
*École Polytechnique de Thiès (EPT)*  
