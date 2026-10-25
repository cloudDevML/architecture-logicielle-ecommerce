# Registre des Décisions d'Architecture (ADR - Architecture Decision Records)

Ce dossier rassemble l'ensemble des décisions architecturales majeures prises dans le cadre du projet **EduMarket** (Plateforme E-Commerce de Formations et Certifications Numériques), pour le module d'**Architecture Logicielle**.

Chaque ADR documente le contexte d'une décision clé, les alternatives analysées, la solution retenue ainsi que ses conséquences positives et ses compromis.

## Index des ADRs

| Identifiant | Titre de la décision | Statut | Date | Portée |
| :--- | :--- | :---: | :---: | :--- |
| **[ADR-001](ADR-001-architecture-microservices.md)** | Choix du style architectural : Microservices vs Monolithe Modulaire | Accepté | Oct. 2026 | Global |
| **[ADR-002](ADR-002-database-per-service.md)** | Stratégie de persistance des données : Database-per-Service | Accepté | Oct. 2026 | Backend / Données |
| **[ADR-003](ADR-003-api-gateway-service-discovery.md)** | Point d'entrée unique et découverte dynamique : Spring Cloud Gateway & Netflix Eureka | Accepté | Oct. 2026 | Réseau / Routage |
| **[ADR-004](ADR-004-communication-asynchrone-kafka.md)** | Découplage événementiel et messagerie asynchrone : Apache Kafka | Accepté | Oct. 2026 | Événements / Intégration |
| **[ADR-005](ADR-005-authentification-jwt-keycloak.md)** | Gestion unifiée de l'identité et sécurité décentralisée : JWT & Keycloak (OAuth2/OIDC) | Accepté | Oct. 2026 | Sécurité / IAM |
| **[ADR-006](ADR-006-configuration-centralisee-spring-cloud-config.md)** | Centralisation et externalisation de la configuration : Spring Cloud Config Server | Accepté | Oct. 2026 | Configuration |
| **[ADR-007](ADR-007-conteneurisation-docker-compose.md)** | Conteneurisation et orchestration des environnements : Docker & Docker Compose | Accepté | Oct. 2026 | Infrastructure |
| **[ADR-008](ADR-008-pipeline-ci-cd-automatise.md)** | Stratégie d'industrialisation et CI/CD multi-plateforme : GitLab CI & GitHub Actions | Accepté | Oct. 2026 | DevOps / Qualité |

---
*Lead Architecte & Rédacteur du Registre : **Abdou Salam MBOUP** (`salamboup2016@gmail.com`)*  
*Séminaire d'Architecture Logicielle Moderne — M. MARONE (EPT, DIC2 Promotion 2026).*
