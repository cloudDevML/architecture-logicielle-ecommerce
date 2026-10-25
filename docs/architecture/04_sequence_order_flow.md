# Diagramme de Séquence : Parcours d'Achat & Inscription

Ce diagramme décrit la cinématique des échanges inter-services lors de la commande d'une formation, du règlement et du déblocage immédiat de l'accès.

## Cinématique des Interactions Inter-Services

```mermaid
sequenceDiagram
    autonumber
    actor Client as Client Web / Mobile
    participant Gateway as API Gateway
    participant CourseSvc as Service Cours et Commandes
    participant Payment as Passerelle Paiement
    participant Kafka as Apache Kafka
    participant Notification as Service Notification

    Client->>Gateway: 1. Consultation catalogue (/api/course/modules)
    Gateway->>CourseSvc: Routage requete
    CourseSvc-->>Client: Formations disponibles et tarifs

    Client->>Gateway: 2. Passer commande (/api/orders)
    Gateway->>CourseSvc: Creation commande
    CourseSvc-->>Client: Commande enregistree (Statut: PENDING)

    Client->>Payment: 3. Paiement (Wave / OM / CB)
    Payment-->>Client: Confirmation de paiement

    Client->>Gateway: 4. Validation reglement (/api/orders/confirm)
    Gateway->>CourseSvc: Enregistrement du paiement
    CourseSvc->>CourseSvc: Mise a jour statut: PAID (Acces debloque)

    CourseSvc->>Kafka: 5. Publication evenement OrderConfirmed
    Kafka->>Notification: Notification d achat
    Notification-->>Client: Notification temps reel

    CourseSvc-->>Client: 6. Confirmation et acces aux cours
```

## Points Clés du Fonctionnement

1. **Routage et Sécurité Centralisés** : L'API Gateway intercepte les requêtes, valide le jeton JWT et transmet le contexte utilisateur en aval.
2. **Atomicité Locale** : La création de la commande et le déblocage de l'accès s'effectuent au sein de la transaction locale de `course-service`.
3. **Découplage Événementiel** : La diffusion des notifications d'achat s'effectue via Apache Kafka de manière non bloquante.
