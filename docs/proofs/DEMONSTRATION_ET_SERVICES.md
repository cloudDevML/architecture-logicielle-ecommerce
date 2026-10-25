# Preuves de Déploiement et Démonstrations — EduMarket

Ce document centralise les éléments de démonstration multimédia, les liens vers les captures vidéo, les accès à la plateforme déployée et les preuves d'exécution des services en environnement conteneurisé.

---

## 1. Vidéos de Démonstration (Application Mobile Flutter & Parcours d'Achat)

Deux formats vidéo sont mis à disposition pour visualiser le fonctionnement complet de la solution :

* 🎬 **[Version Courte — Aperçu Rapide de la Plateforme (Google Drive)](https://drive.google.com/file/d/1ujXcvnCkv5ZaOlWOmqF8WxwzVxbeyew2/view?usp=sharing)**  
  *Survol synthétique des fonctionnalités clés : catalogue de cours, panier, simulation de commande e-commerce et confirmation.*
* 🎥 **[Version Longue — Démonstration Détaillée des Fonctionnalités (Google Drive)](https://drive.google.com/file/d/1830WqaB1pehwhz8m8aXrB58FUUq3Rhd6/view?usp=sharing)**  
  *Parcours exhaustif présentant l'expérience utilisateur complète, l'application mobile Flutter (`lms-mobile-app`), la gestion des rôles et l'interaction des microservices.*

> [!TIP]
> **Conseil de lecture** : Il est recommandé de visionner les vidéos en résolution 1080p. Commencez par la version courte pour une vision d'ensemble, puis approfondissez avec la version longue.

---

## 2. Accès à la Plateforme Déployée en Ligne

L'ensemble de la plateforme est déployé et opérationnel sur serveur Cloud accessible publiquement :

* 🌐 **URL de la Plateforme en Production** : [https://lms-ept.duckdns.org/](https://lms-ept.duckdns.org/)
* 🛒 **Storefront E-Commerce** : [https://lms-ept.duckdns.org/store](https://lms-ept.duckdns.org/store)
* 📑 **Document d'Exploitation Officiel** : [Document_d_exploitation_LMS_EPT.pdf](file:///home/sowma/projects/architecture_logicielle/docs/proofs/Document_d_exploitation_LMS_EPT.pdf)

### Comptes de Démonstration Pré-configurés :
| Profil / Rôle | Identifiant (Email) | Mot de passe | Rôle Métier |
| :--- | :--- | :--- | :--- |
| **Professeur / Formateur** | `aaciss@ept.edu.sn` | `password123` | Création de cours, tarification, publication |
| **Étudiant / Client** | `acharbeladonis@ept.edu.sn` | `password123` | Consultation catalogue, commande, accès aux cours |

---

## 3. Captures d'Écran et Statut des Services

Les captures d'écran des composants en cours d'exécution sont archivées dans le dossier [`docs/proofs/screenshots/`](file:///home/sowma/projects/architecture_logicielle/docs/proofs/screenshots/) :

### 3.1 Conteneurs Docker en fonctionnement (`docker compose ps`)
```bash
docker compose -f lms-microservices/docker-compose.yml ps
```
![État des Conteneurs Docker](screenshots/01_docker_compose_ps.png)
*(Conteneurs opérationnels : `api-gateway`, `discovery-server`, `config-server`, `course-service`, `user-service`, `ai-service`, `announcement-service`, `postgres_db`, `kafka`, `minio`).*

### 3.2 Dashboard Eureka Service Registry (`http://localhost:8761`)
![Eureka Service Registry](screenshots/02_eureka_registry.png)
*(Enregistrement dynamique des microservices avec statut UP et équilibrage de charge).*

### 3.3 Storefront Web E-Commerce (`http://localhost/store`)
![Catalogue Web Storefront](screenshots/03_storefront_web.png)
*(Interface React avec catalogue de formations, tarification unitaire, modal de checkout Wave/OM/CB).*

### 3.4 Application Mobile Flutter (`lms-mobile-app`)
![Écrans Application Mobile](screenshots/04_mobile_app_screens.png)
*(Écrans de navigation, catalogue mobile et session apprenant).*

---

## 4. Preuves d'Exécution et Tests Automatisés

- [Preuve d'exécution des tests unitaires backend (Maven Surefire)](file:///home/sowma/projects/architecture_logicielle/docs/proofs/test-execution-proof.txt) : Validation des tests `OrderServiceTest` et `OrderControllerTest` (7/7 tests réussis avec 0 échec).
- [Preuve de validation de configuration Docker Compose](file:///home/sowma/projects/architecture_logicielle/docs/proofs/docker-compose-validation-proof.txt) : Validation syntaxique, résolution des ports et topologie réseau des microservices.
