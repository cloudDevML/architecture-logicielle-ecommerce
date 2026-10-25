# ADR-003 : Routage et Découverte Dynamique - Spring Cloud Gateway & Netflix Eureka

* **Statut** : Accepté
* **Date** : 2026-10-25
* **Auteurs** : Mouhamadou Abdoulaye SOW, Médoune DIOP, Abdou Salam MBOUP, Matar Faly SAMBE (DIC2 EPT)
* **Contexte Technique** : Couche d'accès et enregistrement des services

---

## 1. Contexte et Problématique

Dans une architecture distribuée, les clients externes (navigateur React, applications mobiles, partenaires) ne doivent pas connaître les adresses IP ou ports internes éphémères des conteneurs. De plus, la gestion transversale du CORS, de la sécurité JWT, du rate-limiting et de l'équilibrage de charge nécessite un point de contrôle unifié.

Nous devions choisir le mécanisme de routage et de découverte parmi :
1. Exposition directe de chaque service avec proxy Nginx statique.
2. Combinaison dynamique **API Gateway (Spring Cloud Gateway)** et **Service Discovery (Netflix Eureka)**.

---

## 2. Alternatives Envisagées

### Option A : Proxy Statique Nginx seul
* **Avantages** : Performances brutes très élevées, empreinte mémoire minimale en C.
* **Inconvénients** : Configuration manuelle statique des hôtes/ports, pas de découverte dynamique sans rechargement de config, intégration complexe avec les tokens de sécurité applicatifs Spring et les filtres réactifs Java.

### Option B : Spring Cloud Gateway + Eureka (Solution Retenue)
* **Avantages** :
  - **Découverte automatique** : Tout microservice qui démarre s'enregistre auprès d'Eureka avec un nom logique (ex: `lb://course-service`).
  - **Équilibrage de charge côté client (Client-side Load Balancing)** : Résolution transparente des adresses sans goulot d'étranglement centralisé.
  - **Filtres programmables** : Validation du jeton JWT, enrichissement des headers de contexte (`X-User-Id`, `X-User-Role`), gestion unifiée des CORS.
  - Architecture non-bloquante basée sur Netty et Spring WebFlux.
* **Inconvénients** : Légère empreinte mémoire Java pour les services d'infrastructure.

---

## 3. Décision

Nous adoptons le couple **Spring Cloud Gateway** (sur le port 8080) et **Netflix Eureka Server** (sur le port 8761) :
- Les clients web communiquent exclusivement avec l'API Gateway via l'URL unifiée `/api/**`.
- L'API Gateway interroge Eureka pour router dynamiquement les requêtes vers les conteneurs cibles.
- Les endpoints publics (`/api/public/**`, `/api/user/auth/**`) sont exemptés de filtrage JWT, tandis que les endpoints protégés (`/api/orders/**`, `/api/course/**`) sont sécurisés par le filtre réactif d'authentification.

---

## 4. Conséquences

### Positives
* Masquage complet de la topologie interne du réseau de conteneurs.
* Ajout aisé de nouvelles répliques de microservices sans reconfigurer l'entrée réseau.
* Découplage maximal entre le frontend et le backend.

### Négatives & Mesures d'atténuation
* *Point de défaillance unique potentiel (SPOF)* : En environnement de production étendu, l'API Gateway peut être instanciée en plusieurs répliques derrière un load-balancer de niveau 4 (AWS ALB).
