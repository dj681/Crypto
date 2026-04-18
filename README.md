# My Crypto Safe (starter Flutter)

## Objectif
Ce dépôt initialise la base de l’application mobile **My Crypto Safe** avec une architecture Flutter claire et une navigation fonctionnelle entre les premiers écrans.

## Architecture
Structure actuelle :

- `lib/main.dart` : point d’entrée, `MaterialApp`, thème et routes.
- `lib/screens/` : écrans de démarrage.
  - `splash_screen.dart`
  - `onboarding_screen.dart`
  - `wallet_create_screen.dart`
  - `wallet_import_screen.dart`
  - `home_screen.dart`
- `lib/widgets/` : composants UI réutilisables (à compléter).
- `lib/models/` : modèles métier (à compléter).
- `lib/services/` : services applicatifs (à compléter).

## Installation
1. Installer Flutter et vérifier l’environnement :
   - `flutter doctor`
2. Installer les dépendances :
   - `flutter pub get`
3. Lancer l’application :
   - `flutter run`

## Dépendances clés
Le fichier `pubspec.yaml` inclut les paquets de base pour la suite du projet :

- `provider`
- `flutter_secure_storage`
- `bip39`
- `web3dart`
- `http`
- `qr_flutter`
- `local_auth`
- `shared_preferences`

## Suite prévue
Prochaines étapes recommandées :

1. Génération/import sécurisé de wallet (BIP39 + stockage chiffré).
2. Gestion d’état globale avec `provider`.
3. Intégration réseau blockchain (`web3dart`) et affichage des soldes.
4. Écrans d’actions (envoi/réception, historique, paramètres).
5. Renforcement sécurité (PIN, biométrie, verrouillage session).
