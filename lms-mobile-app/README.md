# LMS EPT Mobile

Application mobile Flutter de la plateforme LMS de l’École Polytechnique de Thiès.

## Présentation

Cette application permet aux étudiants, enseignants et administrateurs d’accéder aux principales fonctionnalités de la plateforme depuis un terminal mobile : connexion, cours, quiz, devoirs, messagerie, annonces, suivi des notes et autres services pédagogiques.

## Fonctionnalités principales

- Authentification et gestion du profil
- Parcours de cours et contenus pédagogiques
- Quiz, devoirs et résultats
- Annonces, notifications et messagerie
- Présence, emploi du temps et analytics étudiant
- Interface adaptée aux usages mobile

## Stack technique

- Flutter + Dart
- Architecture orientée services
- Intégration avec l’API LMS backend
- Support Android, iOS, web et desktop

## Prérequis

- Flutter SDK 3.x
- Dart SDK
- Android Studio ou Xcode selon la cible de build

## Développement local

```bash
flutter pub get
flutter run
```

## Structure du projet

```text
lib/
├── core/          # constantes, providers, services partagés
├── features/      # écrans et logiques par domaine métier
├── shared/        # widgets et vues communes
└── main.dart      # point d’entrée de l’application
```

