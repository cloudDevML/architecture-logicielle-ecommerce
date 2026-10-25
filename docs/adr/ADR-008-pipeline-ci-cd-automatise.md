# ADR-008 : Stratégie CI/CD Multi-Plateforme - GitLab CI & GitHub Actions

* **Statut** : Accepté
* **Date** : 2026-10-25
* **Auteurs** : Mouhamadou Abdoulaye SOW, Médoune DIOP, Abdou Salam MBOUP, Matar Faly SAMBE (DIC2 EPT)
* **Contexte Technique** : Intégration et livraison continues (CI/CD)

---

## 1. Contexte et Problématique

Dans le cadre des exigences du module d'Architecture Logicielle, la solution doit intégrer une démarche d'industrialisation complète :
« Mettre en place une CI/CD permettant au minimum le build, les tests et le déploiement ; Pour le rendu final, chaque groupe devra rendre le lien de son dépôt GitLab ».

Un projet moderne multi-composants (Microservices Spring Boot Java 21, Frontend React TypeScript, conteneurs Docker) ne peut être validé manuellement. Tout commit doit déclencher des contrôles automatisés pour :
1. Valider la syntaxe et la qualité de code (Linting).
2. Exécuter les suites de tests unitaires et d'intégration (Maven & Jest).
3. Compiler les binaires et fabriquer les images Docker immuables.
4. Préparer ou exécuter le déploiement sur l'environnement cible (Staging/Production).

---

## 2. Alternatives Envisagées

### Option A : Serveur Jenkins Dédié Auto-Hébergé
* **Avantages** : Flexibilité totale des plugins, maîtrise de la machine hôte.
* **Inconvénients** : Maintenance lourde d'un serveur tiers, configuration complexe, consommation de ressources inutile pour un projet académique.

### Option B : GitHub Actions Seul
* **Avantages** : Intégration native avec les dépôts GitHub, runners managés gratuits.
* **Inconvénients** : Ne répond pas à l'exigence formelle du livrable sur GitLab mentionnée par l'enseignant.

### Option C : Double Pipeline Normalisé GitLab CI (`.gitlab-ci.yml`) et GitHub Actions (`ci-cd.yml`) (Solution Retenue)
* **Avantages** :
  - **Portabilité totale** : Le projet peut être hébergé indifféremment sur GitLab (pour la notation officielle) ou sur GitHub (pour le portfolio/travail en équipe).
  - Structure de pipeline déclarative identique en 5 étapes normalisées : `lint`, `test`, `build`, `docker-package`, `deploy`.
  - Utilisation d'images de runners officielles (`maven:3.9-eclipse-temurin-21`, `node:18-alpine`, `docker:latest`).
* **Inconvénients** : Nécessite de maintenir la cohérence des deux fichiers de configuration CI (très simple car la logique sous-jacente est identique).

---

## 3. Décision

Nous mettons en place une configuration CI/CD double et isomorphe :
1. **`.gitlab-ci.yml`** à la racine pour le dépôt officiel GitLab :
   - **Stage `lint`** : Vérification syntaxique ESLint du frontend et validation du format POM.
   - **Stage `test`** : Exécution de `mvn test` sur les microservices et `npm test -- --watchAll=false` sur le frontend.
   - **Stage `build`** : Packaging des JARs exécutables (`mvn package -DskipTests`).
   - **Stage `package`** : Construction des images Docker et tagguage.
   - **Stage `deploy`** : Déploiement automatisé par SSH / script Docker Compose sur l'environnement cloud.

---

## 4. Conséquences

### Positives
* Détection immédiate des régressions avant toute intégration sur la branche `main`.
* Traçabilité complète des builds avec archivage des rapports de tests et artefacts.
* Conformité absolue avec les attentes de l'enseignant (dépôt GitLab + preuves de build).

### Négatives & Mesures d'atténuation
* *Temps d'exécution des pipelines complets* : Optimisé grâce à l'utilisation du cache de dépendances (`.m2/repository` et `node_modules`).
