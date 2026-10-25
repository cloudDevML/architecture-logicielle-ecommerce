# ADR-004 : Communication Asynchrone Événementielle - Apache Kafka

* **Statut** : Accepté
* **Date** : 2026-10-25
* **Auteurs** : Mouhamadou Abdoulaye SOW, Médoune DIOP, Abdou Salam MBOUP, Matar Faly SAMBE (DIC2 EPT)
* **Contexte Technique** : Intégration inter-services et propagation d'événements métiers

---

## 1. Contexte et Problématique

Lorsqu'un utilisateur achète ou souscrit à une formation sur la plateforme EduMarket, plusieurs opérations séquentielles doivent être déclenchées :
1. Enregistrement de la commande et débit du paiement.
2. Inscription de l'étudiant dans le catalogue de formation (accès débloqué).
3. Notification push ou email de confirmation à l'acheteur.
4. Notification d'alerte de vente au formateur/vendeur.
5. Mise à jour des métriques du tableau de bord des ventes.

Si toutes ces actions sont exécutées de manière synchrone par HTTP REST :
- Le temps de réponse pour l'utilisateur final explose (effet cumulatif des latences réseau).
- Une panne passagère du service de notification bloquerait la validation de l'achat (couplage temporel fort).
- Le risque d'incohérence de données est élevé sans protocole de commit distribué.

---

## 2. Alternatives Envisagées

### Option A : Appels Synchrones HTTP REST (OpenFeign)
* **Avantages** : Facilité d'implémentation immédiate, réponse instantanée.
* **Inconvénients** : Couplage temporel strict, propagation en chaîne des pannes (cascading failures), impossibilité de buffering en cas de pic de trafic.

### Option B : Broker de Messages AMQP (RabbitMQ)
* **Avantages** : Routage complexe par exchange, acquittements fins par consommateur.
* **Inconvénients** : Moins adapté au rejeu d'événements (Event Sourcing / Event Log persistant) à grande échelle.

### Option C : Log Distribué Événementiel (Apache Kafka - Solution Retenue)
* **Avantages** :
  - Débit massif et persistance ordonnée des événements sur disque (durable log).
  - Découplage total producteurs/consommateurs (Pub/Sub découplé temporellement).
  - Rejouabilité des événements en cas de reprise sur incident.
  - Modèle idéal pour l'architecture orientée événements (EDA - Event-Driven Architecture).
* **Inconvénients** : Nécessite des ressources mémoire pour le broker.

---

## 3. Décision

Nous intégrons **Apache Kafka** (mode KRaft ou avec contrôleur) comme dorsale d'intégration asynchrone :
- Le topic `order.events` diffuse les événements `OrderCreatedEvent` et `OrderConfirmedEvent`.
- Le topic `notification.events` diffuse les messages d'alerte et de confirmation.
- `course-service` publie les événements d'achat, que `announcement-service` et `user-service` consomment indépendamment sans synchronisation bloquante.

---

## 4. Conséquences

### Positives
* Temps de réponse de l'API de commande quasi-instantané (l'événement est publié et acquitté immédiatement).
* Tolérance aux pannes : si le service de notification est temporairement arrêté, il rattrape son retard dès son redémarrage sans perte de messages.
* Observabilité et auditabilité facilitées grâce à l'historique immuable des événements.

### Négatives & Mesures d'atténuation
* *Complexité de débogage asynchrone* : Atténuée par l'inclusion d'un identifiant de corrélation (`correlationId`) dans les métadonnées de chaque message Kafka.
