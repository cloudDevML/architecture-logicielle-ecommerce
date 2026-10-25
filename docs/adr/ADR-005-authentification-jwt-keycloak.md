# ADR-005 : Gestion de l'Identité et Sécurité Décentralisée - JWT & Keycloak

* **Statut** : Accepté
* **Date** : 2026-10-25
* **Auteurs** : Mouhamadou Abdoulaye SOW, Médoune DIOP, Abdou Salam MBOUP, Matar Faly SAMBE (DIC2 EPT)
* **Contexte Technique** : Authentification, autorisation et propagation des rôles

---

## 1. Contexte et Problématique

Dans une architecture distribuée, authentifier l'utilisateur à chaque requête via un état de session en mémoire côté serveur (sessions HTTP distribuées ou Sticky Sessions) pose des problèmes de scalabilité et introduit un couplage fort avec l'infrastructure. 

Nous devions choisir un mécanisme d'authentification et d'autorisation garantissant :
- L'absence d'état sur les serveurs applicatifs (Stateless / 12-Factor App).
- La propagation sécurisée de l'identité de l'acheteur (ID, nom, rôles : `ROLE_STUDENT`, `ROLE_LECTURER`, `ROLE_ADMIN`) entre les microservices.
- Le respect des standards de sécurité de l'industrie (OAuth2, OpenID Connect).

---

## 2. Alternatives Envisagées

### Option A : Sessions HTTP d'entreprise partagées dans Redis
* **Avantages** : Invalidations de session immédiates en cas de révocation.
* **Inconvénients** : Dépendance réseau à chaque requête vers le cache central Redis, risque de goulot d'étranglement, couplage d'état (Stateful).

### Option B : Jetons Auto-contenus JWT (JSON Web Tokens) signés (Solution Retenue)
* **Avantages** :
  - **Stateless** : Le jeton contient toutes les informations nécessaires (claims, rôles, expiration) et est cryptographiquement signé (HMAC-SHA256 ou RSA).
  - Validation locale ultra-rapide par chaque microservice sans appel réseau supplémentaire.
  - Compatible avec un serveur IAM standard comme **Keycloak** (OpenID Connect / OAuth2).
* **Inconvénients** : Révocation immédiate d'un token avant son expiration plus difficile (géré via des durées de validité courtes combinées à un refresh token).

---

## 3. Décision

Nous adoptons une sécurité basée sur des **tokens JWT normalisés** :
1. **Keycloak / User-Service Auth** : Authentifie l'utilisateur via mot de passe sécurisé (chiffré BCrypt) et génère une paire de tokens (Access Token court et Refresh Token).
2. **Spring Cloud Gateway** : Intercepte les requêtes entrantes, valide la signature du token et extrait le contexte utilisateur.
3. **Propagation de contexte** : L'API Gateway injecte les en-têtes HTTP sécurisés (`X-Auth-User`, `X-Auth-Roles`) pour que les microservices en aval puissent autoriser ou refuser l'accès aux ressources sans recalculer la cryptographie.

---

## 4. Conséquences

### Positives
* Performance maximale : chaque microservice vérifie les permissions en mémoire locale sans interroger de base de session.
* Cloisonnement strict des privilèges (ex: seuls les utilisateurs avec le rôle `ROLE_LECTURER` ou `ROLE_ADMIN` peuvent publier un nouveau cours et fixer un prix).
* Déconnexion et reconnexion transparentes côté frontend React.

### Négatives & Mesures d'atténuation
* *Expiration et renouvellement de token* : Mise en œuvre d'un intercepteur HTTP côté frontend (Axios interceptor) rafraîchissant silencieusement le jeton lorsque le serveur répond avec un code HTTP 401.
