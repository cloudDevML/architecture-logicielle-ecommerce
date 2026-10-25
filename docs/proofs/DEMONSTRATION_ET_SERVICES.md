# Preuves de Déploiement et Démonstrations — EduMarket

Ce document centralise les éléments de démonstration multimédia, les liens vers les captures vidéo et les preuves d'exécution des services en environnement conteneurisé.

---

## 1. Vidéo de Démonstration (Application Mobile Flutter & Parcours d'Achat)

Une démonstration complète du parcours utilisateur (consultation du catalogue de cours, panier, simulation de commande e-commerce, confirmation) a été enregistrée sur l'application mobile Flutter :

- **Lien Google Drive de la vidéo de démonstration** :  
  🔗 **[Lien Vidéo Google Drive — Démonstration EduMarket Mobile](https://drive.google.com/drive/folders/VOTRE_ID_DRIVE_ICI?usp=sharing)**  
  *(Remplacer ce lien par l'URL publique ou partagée de votre vidéo sur Google Drive)*

### Points clés présentés dans la vidéo :
1. Démarrage de l'application mobile Flutter (`lms-mobile-app`).
2. Connexion / Session utilisateur.
3. Consultation du catalogue de cours payants et certifications.
4. Processus de commande (Checkout avec choix du moyen de paiement : Wave, Orange Money, Carte).
5. Validation de la commande et confirmation avec référence unique (`CMD-...`).

---

## 2. Captures d'Écran des Services en Cours d'Exécution

Déposer les captures d'écran dans le dossier `docs/proofs/screenshots/` puis référencer les images ci-dessous :

### 2.1 Conteneurs Docker en fonctionnement (`docker compose ps`)
```bash
docker compose -f lms-microservices/docker-compose.yml ps
```
![État des Conteneurs Docker](screenshots/01_docker_compose_ps.png)
*(Remplacer par votre capture d'écran montrant tous les conteneurs au statut `Up` : eureka, gateway, course-service, etc.)*

### 2.2 Dashboard Eureka Service Registry (`http://localhost:8761`)
![Eureka Service Registry](screenshots/02_eureka_registry.png)
*(Remplacer par la capture montrant les instances enregistrées : API-GATEWAY, CONFIG-SERVER, COURSE-SERVICE, AUTH-SERVICE, etc.)*

### 2.3 Storefront Web E-Commerce (`http://localhost/store`)
![Catalogue Web Storefront](screenshots/03_storefront_web.png)
*(Remplacer par la capture de l'interface d'achat React `/store` avec les cartes de cours et le modal de commande)*

### 2.4 Application Mobile Flutter (`lms-mobile-app`)
![Écrans Application Mobile](screenshots/04_mobile_app_screens.png)
*(Remplacer par les captures d'écran du simulateur ou téléphone Android/iOS)*

---

## 3. Preuves d'Exécution et Tests Automatisés

- [Preuve d'exécution des tests unitaires backend (Maven Surefire)](file:///home/sowma/projects/architecture_logicielle/docs/proofs/test-execution-proof.txt) : Validation des tests `OrderServiceTest` et `OrderControllerTest` (7/7 réussis).
- [Preuve de validation de configuration Docker Compose](file:///home/sowma/projects/architecture_logicielle/docs/proofs/docker-compose-validation-proof.txt) : Validation syntaxique et structurelle des services orchestrés.
