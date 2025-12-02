# Implémentation Firebase - Sauvegarde Cloud Complète

## 📋 Vue d'ensemble du projet actuel

### Architecture actuelle
- **Stockage local** : `SharedPreferences` avec chiffrement basique (base64)
- **Services** :
  - `LocalStorageService` : Gestion du stockage local
  - `TodoService` : Logique métier des tâches
  - `ProjectService` : Logique métier des projets
  - `PreferencesService` : Gestion des préférences
  - `TimerService` : Gestion du timer en temps réel
  - `DataExportImportService` : Export/import de données

### Données à sauvegarder
1. **Tâches (Todos)** : Toutes les propriétés incluant sous-tâches, récurrence, rappels, temps estimé/écoulé
2. **Projets** : Nom, couleur, icône, dates
3. **Préférences utilisateur** : Thème, notifications, paramètres d'affichage, etc.
4. **Données de timer** : État du timer, temps écoulé par tâche

---

## 🏗️ Architecture Firebase proposée

### 1. Services Firebase à utiliser

#### Firebase Authentication
- Authentification par email/mot de passe
- Authentification anonyme (optionnelle pour tester)
- Gestion des sessions utilisateur

#### Cloud Firestore
- Base de données NoSQL en temps réel
- Structure hiérarchique : `users/{userId}/collections/{documents}`
- Synchronisation automatique et offline-first

#### Firebase Storage (optionnel)
- Pour les fichiers volumineux si nécessaire plus tard

### 2. Structure des données dans Firestore

```
users/
  └── {userId}/
      ├── todos/
      │   └── {todoId}/
      │       ├── id: int
      │       ├── title: string
      │       ├── description: string
      │       ├── dueDate: timestamp (nullable)
      │       ├── priority: string (enum: low, medium, high)
      │       ├── projectId: int (nullable)
      │       ├── isCompleted: boolean
      │       ├── parentId: int (nullable)
      │       ├── level: int (0-3)
      │       ├── reminder: timestamp (nullable)
      │       ├── estimatedMinutes: int (nullable)
      │       ├── elapsedMinutes: int
      │       ├── elapsedSeconds: int
      │       ├── createdAt: timestamp
      │       ├── updatedAt: timestamp
      │       ├── recurrenceType: string (enum)
      │       ├── recurrenceDayOfWeek: int (nullable)
      │       ├── recurrenceDayOfMonth: int (nullable)
      │       ├── recurrenceTime: string (nullable, format "HH:mm")
      │       └── isWeeklyPriority: boolean
      │
      ├── projects/
      │   └── {projectId}/
      │       ├── id: int
      │       ├── name: string
      │       ├── color: int (Color.value)
      │       ├── icon: int (IconData.codePoint)
      │       ├── createdAt: timestamp
      │       └── updatedAt: timestamp
      │
      ├── preferences/
      │   └── preferences/
      │       └── {key: value} (Map dynamique)
      │
      └── timer_data/
          └── timer_data/
              └── {key: value} (Map dynamique)
```

### 3. Règles de sécurité Firestore

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Règle pour les utilisateurs authentifiés uniquement
    match /users/{userId} {
      // L'utilisateur ne peut accéder qu'à ses propres données
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Collections sous users/{userId}
      match /todos/{todoId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /projects/{projectId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /preferences/{preferenceId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /timer_data/{timerDataId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

---

## 💻 Implémentation technique

### 1. Dépendances à ajouter

```yaml
dependencies:
  # Firebase Core
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  
  # Optionnel : pour la gestion offline améliorée
  connectivity_plus: ^6.0.5
```

### 2. Structure du service Firebase

Créer un nouveau service `firebase_service.dart` qui :

1. **Gère l'authentification**
   - Connexion/déconnexion
   - État d'authentification
   - Création de compte

2. **Synchronise les données**
   - Tâches (CRUD complet)
   - Projets (CRUD complet)
   - Préférences (lecture/écriture)
   - Données de timer (lecture/écriture)

3. **Gère la synchronisation**
   - Mode offline-first
   - Synchronisation automatique
   - Gestion des conflits
   - Indicateur de statut

4. **Migration depuis le stockage local**
   - Export des données locales
   - Import vers Firebase
   - Vérification de cohérence

### 3. Stratégie de synchronisation

#### Mode Hybride (Recommandé)
- **Stockage local** : Continue d'être utilisé comme cache principal
- **Firebase** : Synchronisation en arrière-plan
- **Avantages** :
  - Fonctionne offline
  - Performance optimale
  - Synchronisation transparente

#### Flux de synchronisation

```
┌─────────────────┐
│  Action locale  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ LocalStorage    │ ◄─── Cache local (toujours à jour)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Firebase Sync   │ ◄─── Synchronisation en arrière-plan
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Cloud Store   │
└─────────────────┘
```

### 4. Gestion des conflits

**Stratégie "Last Write Wins" avec timestamp** :
- Chaque document a un `updatedAt` timestamp
- En cas de conflit, la version la plus récente gagne
- Log des conflits pour l'utilisateur (optionnel)

**Alternative : Merge intelligent** :
- Pour les préférences : merge des clés
- Pour les tâches/projets : comparaison des timestamps

---

## 📝 Plan d'implémentation étape par étape

### Phase 1 : Configuration Firebase
1. ✅ Créer un projet Firebase
2. ✅ Configurer Firebase dans l'app Flutter
3. ✅ Ajouter les dépendances
4. ✅ Configurer les règles de sécurité Firestore

### Phase 2 : Service d'authentification
1. ✅ Créer `FirebaseAuthService`
2. ✅ Implémenter connexion/déconnexion
3. ✅ Gérer l'état d'authentification
4. ✅ Intégrer dans l'UI

### Phase 3 : Service de synchronisation
1. ✅ Créer `FirebaseSyncService`
2. ✅ Implémenter la synchronisation des tâches
3. ✅ Implémenter la synchronisation des projets
4. ✅ Implémenter la synchronisation des préférences
5. ✅ Implémenter la synchronisation des données de timer

### Phase 4 : Intégration avec les services existants
1. ✅ Modifier `LocalStorageService` pour déclencher la sync
2. ✅ Adapter `TodoService` pour utiliser Firebase
3. ✅ Adapter `ProjectService` pour utiliser Firebase
4. ✅ Adapter `PreferencesService` pour utiliser Firebase

### Phase 5 : Migration des données
1. ✅ Créer un service de migration
2. ✅ Exporter les données locales
3. ✅ Importer vers Firebase
4. ✅ Vérification et validation

### Phase 6 : Synchronisation en temps réel
1. ✅ Écouter les changements Firestore
2. ✅ Mettre à jour le cache local
3. ✅ Notifier l'UI des changements

### Phase 7 : Gestion offline
1. ✅ Activer la persistance Firestore
2. ✅ Gérer la queue de synchronisation
3. ✅ Indicateur de statut de connexion

---

## 🔧 Détails d'implémentation

### Service Firebase principal

Le service principal devra :

1. **Initialiser Firebase**
   ```dart
   await Firebase.initializeApp();
   await Firestore.instance.enablePersistence();
   ```

2. **Gérer l'authentification**
   - Écouter les changements d'état
   - Gérer les erreurs d'authentification
   - Persister la session

3. **Synchroniser les données**
   - Écouter les changements Firestore
   - Mettre à jour le cache local
   - Envoyer les modifications locales vers Firebase

4. **Gérer les conflits**
   - Comparer les timestamps
   - Appliquer la stratégie de résolution
   - Notifier l'utilisateur si nécessaire

### Exemple de méthode de synchronisation

```dart
Future<void> syncTodos() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  // 1. Récupérer les todos depuis Firebase
  final firestoreTodos = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('todos')
      .get();
  
  // 2. Récupérer les todos locaux
  final localTodos = LocalStorageService().todos;
  
  // 3. Fusionner intelligemment
  final mergedTodos = _mergeTodos(localTodos, firestoreTodos);
  
  // 4. Mettre à jour le cache local
  await LocalStorageService().updateAllTodos(mergedTodos);
  
  // 5. Synchroniser vers Firebase si nécessaire
  await _syncToFirebase(mergedTodos);
}
```

### Gestion de la synchronisation automatique

```dart
class FirebaseSyncService {
  Timer? _syncTimer;
  bool _isSyncing = false;
  
  void startAutoSync() {
    // Synchronisation toutes les 5 minutes
    _syncTimer = Timer.periodic(Duration(minutes: 5), (_) {
      if (!_isSyncing) {
        syncAll();
      }
    });
  }
  
  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    try {
      await Future.wait([
        syncTodos(),
        syncProjects(),
        syncPreferences(),
        syncTimerData(),
      ]);
    } finally {
      _isSyncing = false;
    }
  }
}
```

---

## 🎯 Points d'attention

### 1. Performance
- **Batch writes** : Grouper les écritures pour réduire les coûts
- **Pagination** : Pour les grandes collections
- **Index Firestore** : Créer les index nécessaires

### 2. Coûts Firebase
- **Firestore** : 
  - Lecture : ~$0.06 pour 100k documents
  - Écriture : ~$0.18 pour 100k documents
  - Stockage : ~$0.18/Go/mois
- **Recommandation** : Limiter les synchronisations fréquentes

### 3. Sécurité
- Règles Firestore strictes
- Validation côté serveur
- Chiffrement des données sensibles (optionnel)

### 4. Expérience utilisateur
- Indicateur de synchronisation
- Mode offline transparent
- Gestion des erreurs utilisateur-friendly

---

## 🚀 Migration depuis le stockage local

### Processus de migration

1. **Détection de première connexion**
   ```dart
   bool hasMigrated = await PreferencesService()
       .getPreference<bool>('firebase_migrated') ?? false;
   ```

2. **Export des données locales**
   ```dart
   final localData = {
     'todos': LocalStorageService().todos,
     'projects': LocalStorageService().projects,
     'preferences': PreferencesService().getAllPreferences(),
     'timerData': LocalStorageService().timerData,
   };
   ```

3. **Import vers Firebase**
   ```dart
   await FirebaseSyncService().importData(localData);
   ```

4. **Marquer comme migré**
   ```dart
   await PreferencesService()
       .setPreference('firebase_migrated', true);
   ```

---

## 📊 Monitoring et debugging

### Logs à implémenter
- État de synchronisation
- Erreurs de connexion
- Conflits de données
- Performance des requêtes

### Métriques à suivre
- Temps de synchronisation
- Taux d'erreur
- Utilisation de la bande passante
- Coûts Firebase

---

## ✅ Checklist d'implémentation

- [ ] Configuration Firebase (projet, Android, iOS)
- [ ] Ajout des dépendances
- [ ] Création du service d'authentification
- [ ] Création du service de synchronisation
- [ ] Implémentation de la sync des tâches
- [ ] Implémentation de la sync des projets
- [ ] Implémentation de la sync des préférences
- [ ] Implémentation de la sync des données de timer
- [ ] Gestion des conflits
- [ ] Migration depuis le stockage local
- [ ] Synchronisation en temps réel
- [ ] Gestion offline
- [ ] Tests unitaires
- [ ] Tests d'intégration
- [ ] Documentation utilisateur

---

## 🔄 Prochaines étapes recommandées

1. **Commencer par l'authentification** : Base solide pour tout le reste
2. **Synchronisation des tâches** : Fonctionnalité principale
3. **Synchronisation des projets** : Complémentaire
4. **Préférences et timer** : Données secondaires
5. **Optimisations** : Performance et coûts

---

## 📚 Ressources

- [Firebase Flutter Documentation](https://firebase.flutter.dev/)
- [Cloud Firestore Best Practices](https://firebase.google.com/docs/firestore/best-practices)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [FlutterFire Documentation](https://firebase.flutter.dev/docs/overview)





