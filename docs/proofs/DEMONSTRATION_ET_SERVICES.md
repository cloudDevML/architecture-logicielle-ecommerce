# Preuves de Déploiement et Démonstrations — EduMarket

Ce document centralise les éléments de démonstration multimédia, les liens vers les captures vidéo, les accès à la plateforme déployée en ligne et le document d'exploitation officiel.

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

## 3. Déploiement Local & Validation des Services

Pour tester l'ensemble de la pile de microservices localement :

```bash
# 1. Se positionner dans le dossier des microservices
cd lms-microservices

# 2. Configurer l'environnement
cp .env.example .env

# 3. Lancer les conteneurs
docker compose up -d
```

### URLs Locales :
- **Storefront Web** : `http://localhost/store`
- **API Gateway** : `http://localhost:8080`
- **Eureka Discovery Registry** : `http://localhost:8761`
- **Documentation OpenAPI / Swagger** : `http://localhost:8080/swagger-ui.html`
