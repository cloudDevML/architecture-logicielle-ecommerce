# ADR-007 : Conteneurisation et Orchestration - Docker & Docker Compose

* **Statut** : Accepté
* **Date** : 2026-10-25
* **Auteurs** : Mouhamadou Abdoulaye SOW, Médoune DIOP, Abdou Salam MBOUP, Matar Faly SAMBE (DIC2 EPT)
* **Contexte Technique** : Packaging et orchestration du déploiement du MVP

---

## 1. Contexte et Problématique

Pour valider le MVP dans le cadre du module d'Architecture Logicielle, la plateforme doit pouvoir être lancée en une seule commande reproductible sur n'importe quel poste d'enseignant ou serveur cloud, sans dépendance vis-à-vis des versions de Java, Node, PostgreSQL ou Kafka installées sur la machine hôte.

Nous devions choisir le niveau d'orchestration adapté :
1. Installation directe sur machine nue / scripts shell locaux.
2. **Docker & Docker Compose**.
3. Cluster Kubernetes (K8s) complet.

---

## 2. Alternatives Envisagées

### Option A : Déploiement sur Machine Nue (Bare Metal)
* **Avantages** : Aucun overhead de virtualisation.
* **Inconvénients** : Problème classique « ça marche sur ma machine », conflits de versions de Java (Java 17 vs Java 21) et de ports réseau, installation longue et fastidieuse de 5 bases de données et brokers.

### Option B : Kubernetes (K8s / Minikube)
* **Avantages** : Standard absolu pour la haute disponibilité et l'auto-scaling à grande échelle en production d'entreprise.
* **Inconvénients** : Complexité excessive pour un MVP universitaire, consommation excessive de mémoire et CPU sur un ordinateur portable, barrière d'entrée élevée pour les évaluateurs.

### Option C : Docker & Docker Compose (Solution Retenue)
* **Avantages** :
  - **Reproductibilité totale** : Images immuables multi-stage builds basées sur OpenJDK 21 et Nginx Alpine.
  - Déclaration claire de toute l'infrastructure (services, réseaux virtuels, volumes persistants, variables d'environnement, healthchecks) dans un unique fichier `docker-compose.yml`.
  - Démarrage et arrêt en une seule ligne de commande (`docker-compose up -d`).
  - Allocation fine des ressources (CPU et RAM limits) pour tourner sur une machine de développement standard.
* **Inconvénients** : Ne gère pas nativement le multi-nœuds avec failover automatique (ce qui est inutile pour ce périmètre de MVP).

---

## 3. Décision

Nous adoptons **Docker** avec des **Dockerfile multi-stages** pour chaque service et **Docker Compose** pour l'orchestration locale et de staging :
- Les Dockerfiles compilent le code via Maven / Node puis ne conservent que le runtime JRE / Nginx minimal pour alléger les images finales.
- Un réseau virtuel interne `lms-network` isole les microservices d'infrastructure du réseau public.
- Les volumes persistants (`postgres_data`, `minio_data`, `kafka_data`) garantissent la conservation des données entre les redémarrages.

---

## 4. Conséquences

### Positives
* Déploiement "Zero-Config" pour l'évaluateur : `docker-compose up -d` suffit pour démarrer l'ensemble de l'écosystème.
* Parité parfaite entre l'environnement de développement, de test CI et de production AWS.
* Isolation totale des dépendances logicielles.

### Négatives & Mesures d'atténuation
* *Temps de premier téléchargement des images* : Atténué par la publication préalable des images sur Docker Hub (`emdy1/lms-...:latest`).
