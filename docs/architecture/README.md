# Dossier d'Architecture & Diagrammes Système (Modèle C4)

Ce dossier documente l'architecture logicielle complète de la plateforme **EduMarket** (E-Commerce de Formations et Certifications Numériques) selon le modèle **C4 (Context, Containers, Components, Code)** complété par les diagrammes de séquence et de déploiement physique.

---

## Sommaire des Diagrammes

1. **[C4 Niveau 1 : Diagramme de Contexte Système](01_c4_system_context.md)**  
   Vision macroscopique montrant les acteurs (Clients, Formateurs, Administrateurs) et les systèmes tiers (Passerelle de paiement, Envoi d'emails, Modèles IA).

2. **[C4 Niveau 2 : Diagramme des Conteneurs](02_c4_container_diagram.md)**  
   Cartographie des applications exécutables, passerelle d'API, serveurs de découverte et de configuration, microservices métiers, bases de données et bus de messages.

3. **[C4 Niveau 3 : Diagramme des Composants](03_c4_component_diagram.md)**  
   Zoom sur l'organisation interne du microservice central `course-service` (Gestion du Catalogue, Pricing et Commandes/Inscriptions).

4. **[Diagramme de Séquence : Parcours d'Achat et Souscription](04_sequence_order_flow.md)**  
   Cinématique complète des interactions inter-services lors de la commande d'une formation, du paiement et de la confirmation asynchrone par Kafka.

5. **[Diagramme de Déploiement : Topologie Docker & Cloud](05_deployment_topology.md)**  
   Organisation des réseaux Docker, volumes persistants, exposition des ports et hébergement cloud.

6. **[Grille d'Audit Architectural & Conformité Séminaire M. MARONE](ARCHITECTURE_AUDIT_MARONE.md)**  
   Évaluation point par point de la conformité du projet selon les 4 modules du séminaire (DDD, Hexagonal, CAP, CI/CD, Observabilité).

---

## Aperçu Visuel Rapide (C4 Niveau 1 - Contexte)

```mermaid
C4Context
    title Diagramme de Contexte Système - EduMarket E-Commerce Platform

    Person(customer, "Apprenant / Client", "Achète des formations certifiantes, suit ses cours et passe des quiz.")
    Person(lecturer, "Formateur / Vendeur", "Publie des formations, fixe les tarifs et suit ses ventes.")
    Person(admin, "Administrateur", "Pilote la plateforme, modère le catalogue et supervise les transactions.")

    Enterprise_Boundary(b0, "Plateforme EduMarket") {
        System(edumarket, "EduMarket Platform", "Plateforme e-commerce distribuée de vente et de diffusion de formations numériques certifiantes.")
    }

    System_Ext(payment_gw, "Passerelle de Paiement", "Simulation Stripe / Wave / Orange Money pour la validation des règlements.")
    System_Ext(ai_llm, "Fournisseurs LLM (Groq / Gemini)", "Modèles d'IA générative et embeddings vectoriels pour l'orientation personnalisée.")
    System_Ext(storage_s3, "Stockage Objets S3 (MinIO)", "Stockage immuable des vidéos de formation et supports PDF.")

    Rel(customer, edumarket, "Consulte le catalogue, commande des formations et étudie", "HTTPS")
    Rel(lecturer, edumarket, "Publie des cours, gère les prix et consulte ses revenus", "HTTPS")
    Rel(admin, edumarket, "Supervise les ventes, utilisateurs et métriques", "HTTPS")

    Rel(edumarket, payment_gw, "Autorise et valide les transactions financières", "REST / Webhook")
    Rel(edumarket, ai_llm, "Génère des recommandations et résumés pédagogiques", "REST HTTPS")
    Rel(edumarket, storage_s3, "Sauvegarde et distribue les médias lourds", "S3 API")
```

---

*Conforme aux exigences du séminaire d'Architecture Logicielle 2026.*
