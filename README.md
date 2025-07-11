# 📝 Todo App - Application de Gestion de Tâches Flutter

Une application de gestion de tâches moderne et intuitive développée avec Flutter, offrant une expérience utilisateur fluide avec des fonctionnalités avancées.

![Flutter](https://img.shields.io/badge/Flutter-3.5.4-blue?style=for-the-badge&logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.5.4-blue?style=for-the-badge&logo=dart)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

## ✨ Fonctionnalités Principales

### 🎯 Gestion des Tâches
- **Création et édition** de tâches avec descriptions détaillées
- **Sous-tâches hiérarchiques** (jusqu'à 3 niveaux de profondeur)
- **Priorités** : Basse, Moyenne, Haute
- **Dates d'échéance** et rappels personnalisables
- **Marquage rapide** des tâches comme terminées (avec sous-tâches)

### 📁 Organisation par Projets
- **Projets personnalisables** avec couleurs uniques
- **Vue "Toutes les tâches"** pour une vue d'ensemble
- **Comptage intelligent** des tâches non terminées par projet
- **Gestion des projets** (ajout, suppression, modification)

### ⏰ Suivi du Temps
- **Timer intégré** pour chaque tâche
- **Temps estimé** vs temps réel
- **Suivi en temps réel** avec pause/reprise
- **Statistiques** de temps par tâche

### 🔔 Notifications Intelligentes
- **Rappels programmables** pour chaque tâche
- **Navigation directe** vers la tâche depuis la notification
- **Notifications persistantes** même en mode économie d'énergie
- **Gestion des permissions** automatique

### 🎨 Interface Moderne
- **Thèmes personnalisables** : 8 couleurs disponibles
- **Mode sombre/clair** indépendant
- **Animations fluides** et transitions modernes
- **Design responsive** adapté à tous les écrans

### ⚙️ Paramètres Avancés
- **Affichage des descriptions** (optionnel)
- **Affichage des tâches terminées** (optionnel)
- **Tri personnalisable** : Date, Nom, Priorité, Échéance
- **Sauvegarde automatique** des préférences

### 💾 Gestion des Données
- **Sauvegarde locale** sécurisée avec chiffrement
- **Export/Import** des données (JSON)
- **Migration automatique** des anciennes données
- **Synchronisation** des préférences utilisateur

## 📱 Captures d'Écran

### Écran Principal
![Écran Principal](screenshots/main_screen.png)
*Interface principale avec liste des tâches et sidebar des projets*

### Gestion des Tâches
![Gestion des Tâches](screenshots/task_management.png)
*Modal de création/édition de tâche avec sous-tâches*

### Paramètres et Thèmes
![Paramètres](screenshots/settings.png)
*Écran des paramètres avec sélection de thème*

### Notifications
![Notifications](screenshots/notifications.png)
*Système de notifications avec navigation directe*

## 🚀 Installation

### Prérequis
- Flutter SDK 3.5.4 ou supérieur
- Dart 3.5.4 ou supérieur
- Android Studio / VS Code
- Un appareil Android ou émulateur

### Étapes d'Installation

1. **Cloner le repository**
```bash
git clone https://github.com/4coma/todoist-private.git
cd todoist-private
```

2. **Installer les dépendances**
```bash
flutter pub get
```

3. **Configurer l'icône personnalisée** (optionnel)
```bash
# Placer votre icône dans assets/icon/icon.png
flutter pub run flutter_launcher_icons:main
```

4. **Lancer l'application**
```bash
flutter run
```

### Build pour Production

**Android APK :**
```bash
flutter build apk --release
```

**Android App Bundle :**
```bash
flutter build appbundle --release
```

## 🛠️ Architecture Technique

### Structure du Projet
```
lib/
├── main.dart                 # Point d'entrée de l'application
├── models/                   # Modèles de données
│   ├── todo_item.dart       # Modèle de tâche
│   └── project.dart         # Modèle de projet
├── services/                 # Services métier
│   ├── local_storage_service.dart    # Gestion du stockage
│   ├── notification_service.dart     # Gestion des notifications
│   ├── timer_service.dart           # Gestion du timer
│   └── preferences_service.dart     # Gestion des préférences
├── themes.dart              # Configuration des thèmes
└── widgets/                 # Composants réutilisables
    └── modern_components.dart
```

### Technologies Utilisées
- **Flutter** : Framework de développement cross-platform
- **SharedPreferences** : Stockage local des préférences
- **Awesome Notifications** : Système de notifications avancé
- **Flutter Animate** : Animations fluides et modernes
- **File Picker** : Gestion des fichiers pour export/import

### Fonctionnalités Techniques
- **Architecture modulaire** avec séparation des responsabilités
- **Gestion d'état** avec StatefulWidget et setState
- **Stockage sécurisé** avec chiffrement des données
- **Notifications persistantes** avec gestion des permissions
- **Timer en temps réel** avec mise à jour de l'interface

## 📋 Fonctionnalités Détaillées

### Gestion des Tâches
- ✅ Création de tâches avec titre, description, priorité
- ✅ Sous-tâches hiérarchiques (3 niveaux max)
- ✅ Dates d'échéance avec rappels
- ✅ Marquage rapide comme terminée
- ✅ Suppression avec confirmation
- ✅ Édition complète des propriétés

### Système de Projets
- ✅ Création de projets avec couleurs personnalisées
- ✅ Vue "Toutes les tâches" pour vue d'ensemble
- ✅ Comptage des tâches non terminées
- ✅ Gestion des projets (ajout, suppression)

### Suivi du Temps
- ✅ Timer intégré par tâche
- ✅ Temps estimé vs temps réel
- ✅ Pause/reprise du timer
- ✅ Affichage en temps réel
- ✅ Statistiques de temps

### Notifications
- ✅ Rappels programmables
- ✅ Navigation directe depuis notification
- ✅ Gestion des permissions
- ✅ Notifications persistantes

### Personnalisation
- ✅ 8 thèmes de couleurs disponibles
- ✅ Mode sombre/clair
- ✅ Animations fluides
- ✅ Paramètres d'affichage

## 🔧 Configuration

### Variables d'Environnement
Aucune variable d'environnement requise - l'application fonctionne entièrement en local.

### Permissions Android
```xml
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### Permissions iOS
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

## 📊 Statistiques du Projet

- **Lignes de code** : ~3,500+
- **Fichiers** : 50+
- **Dépendances** : 15+
- **Tests** : Couverture complète des fonctionnalités principales

## 🤝 Contribution

Les contributions sont les bienvenues ! Voici comment contribuer :

1. **Fork** le projet
2. **Créer** une branche pour votre fonctionnalité
3. **Commit** vos changements
4. **Push** vers la branche
5. **Ouvrir** une Pull Request

### Guidelines de Code
- Respecter les conventions Dart/Flutter
- Ajouter des commentaires pour les fonctionnalités complexes
- Tester les nouvelles fonctionnalités
- Maintenir la cohérence du design

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🙏 Remerciements

- **Flutter Team** pour le framework exceptionnel
- **Awesome Notifications** pour le système de notifications
- **Flutter Animate** pour les animations fluides
- **Communauté Flutter** pour l'inspiration et le support

## 📞 Support

Pour toute question ou problème :
- 📧 Email : [votre-email@example.com]
- 🐛 Issues : [GitHub Issues](https://github.com/4coma/todoist-private/issues)
- 💬 Discussions : [GitHub Discussions](https://github.com/4coma/todoist-private/discussions)

---

**⭐ N'oubliez pas de mettre une étoile si ce projet vous a été utile ! ⭐**
