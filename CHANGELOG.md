# Changelog

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-19

### Ajouté
- ✅ Application de gestion de tâches complète
- ✅ Système de projets avec couleurs personnalisables
- ✅ Sous-tâches hiérarchiques (jusqu'à 3 niveaux)
- ✅ Système de priorités (Basse, Moyenne, Haute)
- ✅ Dates d'échéance avec rappels
- ✅ Timer intégré pour chaque tâche
- ✅ Notifications intelligentes avec navigation directe
- ✅ 8 thèmes de couleurs disponibles
- ✅ Mode sombre/clair indépendant
- ✅ Animations fluides et transitions modernes
- ✅ Sauvegarde locale sécurisée
- ✅ Export/Import des données (JSON)
- ✅ Paramètres avancés (affichage descriptions, tâches terminées)
- ✅ Vue "Toutes les tâches" par défaut
- ✅ Bouton "Marquer comme terminée" dans le modal de détail
- ✅ Icône personnalisée avec flutter_launcher_icons
- ✅ Suppression de la bannière de debug

### Modifié
- 🔄 Amélioration de la persistance des données
- 🔄 Optimisation des performances
- 🔄 Interface utilisateur plus intuitive
- 🔄 Gestion des notifications améliorée

### Corrigé
- 🐛 Problème de persistance des données au redémarrage
- 🐛 Navigation depuis les notifications
- 🐛 Affichage des tâches terminées dans les projets
- 🐛 Conflit de variables pour l'affichage des tâches terminées

### Technique
- 🏗️ Architecture modulaire avec séparation des responsabilités
- 🏗️ Gestion d'état avec StatefulWidget
- 🏗️ Stockage sécurisé avec chiffrement
- 🏗️ Notifications persistantes avec gestion des permissions
- 🏗️ Timer en temps réel avec mise à jour de l'interface

## [0.9.0] - 2024-12-18

### Ajouté
- ✅ Système de notifications de base
- ✅ Timer simple pour les tâches
- ✅ Thèmes de couleurs de base
- ✅ Sauvegarde locale

### Modifié
- 🔄 Interface utilisateur améliorée
- 🔄 Gestion des projets

### Corrigé
- 🐛 Problèmes de persistance des données

## [0.8.0] - 2024-12-17

### Ajouté
- ✅ Gestion des tâches de base
- ✅ Système de projets
- ✅ Interface utilisateur moderne

### Modifié
- 🔄 Structure du projet
- 🔄 Organisation du code

---

## Types de modifications

- `Ajouté` pour les nouvelles fonctionnalités
- `Modifié` pour les changements dans les fonctionnalités existantes
- `Déprécié` pour les fonctionnalités qui seront bientôt supprimées
- `Supprimé` pour les fonctionnalités supprimées
- `Corrigé` pour les corrections de bugs
- `Sécurité` pour les corrections de vulnérabilités
- `Technique` pour les améliorations techniques 