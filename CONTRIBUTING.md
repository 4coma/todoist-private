# Guide de Contribution

Merci de votre intérêt pour contribuer à Todo App ! Ce document vous guidera à travers le processus de contribution.

## 🚀 Comment Contribuer

### 1. Fork et Clone

1. **Fork** le repository sur GitHub
2. **Clone** votre fork localement :
```bash
git clone https://github.com/votre-username/todoist-private.git
cd todoist-private
```

### 2. Configuration de l'Environnement

1. **Installer Flutter** (version 3.5.4 ou supérieure)
2. **Installer les dépendances** :
```bash
flutter pub get
```

3. **Vérifier que tout fonctionne** :
```bash
flutter run
```

### 3. Créer une Branche

Créez une branche pour votre fonctionnalité :
```bash
git checkout -b feature/nom-de-votre-fonctionnalite
```

### 4. Développer

- **Écrire du code propre** et bien documenté
- **Suivre les conventions** Dart/Flutter
- **Tester** vos modifications
- **Ajouter des commentaires** pour les fonctionnalités complexes

### 5. Commiter

```bash
git add .
git commit -m "feat: ajouter une nouvelle fonctionnalité

- Description détaillée des changements
- Impact sur l'utilisateur
- Tests effectués"
```

### 6. Pousser et Créer une Pull Request

```bash
git push origin feature/nom-de-votre-fonctionnalite
```

Puis créez une Pull Request sur GitHub avec :
- **Description claire** de la fonctionnalité
- **Captures d'écran** si applicable
- **Tests effectués**

## 📋 Standards de Code

### Conventions Dart/Flutter

- **Nommage** : `snake_case` pour les variables et fonctions
- **Classes** : `PascalCase` pour les noms de classes
- **Constantes** : `SCREAMING_SNAKE_CASE`
- **Indentation** : 2 espaces

### Structure des Fichiers

```
lib/
├── models/          # Modèles de données
├── services/        # Services métier
├── widgets/         # Composants réutilisables
└── themes.dart      # Configuration des thèmes
```

### Commentaires

```dart
/// Documentation pour les classes et méthodes publiques
class TodoItem {
  /// Crée une nouvelle tâche avec les paramètres donnés
  TodoItem({
    required this.title,
    this.description,
    this.priority = Priority.medium,
  });
}
```

## 🧪 Tests

### Tests Unitaires

```bash
flutter test
```

### Tests d'Intégration

```bash
flutter test integration_test/
```

### Tests Manuels

- ✅ Tester sur Android
- ✅ Tester sur iOS (si possible)
- ✅ Tester les notifications
- ✅ Tester la persistance des données

## 🐛 Signaler un Bug

### Avant de Signaler

1. **Vérifier** que le bug n'a pas déjà été signalé
2. **Tester** sur la dernière version
3. **Reproduire** le bug de manière cohérente

### Template de Bug Report

```markdown
**Description du Bug**
Description claire et concise du bug.

**Étapes pour Reproduire**
1. Aller à '...'
2. Cliquer sur '...'
3. Faire défiler jusqu'à '...'
4. Voir l'erreur

**Comportement Attendu**
Description de ce qui devrait se passer.

**Captures d'Écran**
Si applicable, ajouter des captures d'écran.

**Environnement**
- OS : [ex: iOS, Android]
- Version : [ex: 1.0.0]
- Appareil : [ex: iPhone 12, Samsung Galaxy S21]

**Informations Supplémentaires**
Toute autre information pertinente.
```

## 💡 Proposer une Fonctionnalité

### Template de Feature Request

```markdown
**Problème à Résoudre**
Description claire du problème que cette fonctionnalité résoudrait.

**Solution Proposée**
Description de la solution souhaitée.

**Alternatives Considérées**
Autres solutions que vous avez considérées.

**Informations Supplémentaires**
Captures d'écran, maquettes, etc.
```

## 📝 Types de Contributions

### 🎯 Fonctionnalités
- Nouvelles fonctionnalités
- Améliorations de l'interface
- Optimisations de performance

### 🐛 Corrections
- Corrections de bugs
- Améliorations de sécurité
- Corrections de documentation

### 📚 Documentation
- Amélioration du README
- Ajout de commentaires
- Guides d'utilisation

### 🧪 Tests
- Tests unitaires
- Tests d'intégration
- Tests de performance

## 🤝 Code Review

### Critères d'Acceptation

- ✅ **Code propre** et bien documenté
- ✅ **Tests** passent
- ✅ **Conventions** respectées
- ✅ **Performance** acceptable
- ✅ **Sécurité** vérifiée

### Processus de Review

1. **Automatique** : Tests CI/CD
2. **Manuel** : Review par les maintainers
3. **Feedback** : Commentaires et suggestions
4. **Mise à jour** : Corrections si nécessaire
5. **Merge** : Intégration dans la branche principale

## 🏷️ Labels Utilisés

- `bug` : Problème à corriger
- `enhancement` : Amélioration de fonctionnalité
- `feature` : Nouvelle fonctionnalité
- `documentation` : Amélioration de la documentation
- `good first issue` : Bon pour débuter
- `help wanted` : Besoin d'aide
- `priority: high` : Priorité élevée
- `priority: low` : Priorité faible

## 📞 Support

### Questions Générales
- 💬 [GitHub Discussions](https://github.com/4coma/todoist-private/discussions)
- 📧 Email : [votre-email@example.com]

### Problèmes Techniques
- 🐛 [GitHub Issues](https://github.com/4coma/todoist-private/issues)

## 🙏 Remerciements

Merci à tous les contributeurs qui participent à l'amélioration de Todo App !

---

**N'oubliez pas : Chaque contribution, même petite, est appréciée ! 🌟** 