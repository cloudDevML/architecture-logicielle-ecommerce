# C4 Niveau 2 : Diagramme des Conteneurs

Le diagramme ci-dessous présente la vue simplifiée des conteneurs applicatifs de la plateforme **EduMarket** et leurs flux d'échange essentiels.

## Architecture des Conteneurs

```mermaid
flowchart TD
    subgraph Clients["Clients"]
        Web["Web Frontend (React)"]
        Mobile["Mobile App (Flutter)"]
    end

    subgraph Entrypoint["Point d'Entree"]
        Gateway["API Gateway (Port 8080)"]
    end

    subgraph CoreServices["Microservices Metiers"]
        CourseSvc["Course & Order Service (8082)"]
        UserSvc["User Service (8081)"]
        NotifSvc["Announcement Service (8085)"]
    end

    subgraph Persistence["Donnees & Evenements"]
        Postgres[("PostgreSQL")]
        Kafka["Apache Kafka"]
    end

    Web --> Gateway
    Mobile --> Gateway

    Gateway --> CourseSvc
    Gateway --> UserSvc
    Gateway --> NotifSvc

    CourseSvc --> Postgres
    UserSvc --> Postgres
    CourseSvc --> Kafka
    Kafka --> NotifSvc
```

## Description des Conteneurs Principaux

- **Clients (Web / Mobile)** : Interfaces utilisateur React et Flutter permettant la consultation du catalogue et la souscription aux cours.
- **API Gateway (Spring Cloud Gateway)** : Point d'accès unique exposant les routes sécurisées `/api/**` avec filtrage JWT et répartition de charge.
- **Course & Order Service** : Gestion des catalogues de formations, modules, tarification et cycle de vie des commandes (`Order`).
- **User Service** : Gestion des utilisateurs, profils, inscriptions et authentification.
- **Announcement Service** : Diffusion des alertes et notifications d'achat via WebSocket.
- **PostgreSQL & Kafka** : Persistance relationnelle par microservice et bus de messages pour la communication asynchrone.
