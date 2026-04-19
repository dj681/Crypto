# My Crypto Safe

Application mobile Flutter de portefeuille crypto sécurisé.

## Architecture

```
lib/
  main.dart                       # Point d'entrée : MultiProvider, NavigatorKey, cycle de vie
  models/
    wallet.dart                   # Modèle immuable du portefeuille (sans secrets)
    tx_record.dart                # Enregistrement local de transaction
    market_ticker.dart            # Données d'une paire du marché Binance
  services/
    wallet_service.dart           # BIP-39, dérivation de clé, stockage chiffré
    blockchain_service.dart       # Client web3dart : balance, envoi, gas
    security_service.dart         # PIN (SHA-256), biométrie (local_auth)
    market_service.dart           # API publique Binance (ticker 24h)
  providers/
    wallet_provider.dart          # État global du portefeuille + historique
    blockchain_provider.dart      # Solde ETH, envoi de transactions
    security_provider.dart        # Session : verrouillage, PIN, biométrie
    market_provider.dart          # État du marché Binance
  screens/
    splash_screen.dart            # Chargement initial (wallet/session)
    onboarding_screen.dart        # Choix : créer ou importer
    wallet_create_screen.dart     # Génération BIP-39 + confirmation des mots
    wallet_import_screen.dart     # Import par phrase mnémonique
    home_screen.dart              # Interface principale (Accueil, Trader, Récompense, Découvrir, Convertir)
    market_screen.dart            # Vue marché Binance complète + recherche + actions achat/vente
    send_screen.dart              # Envoi ETH
    receive_screen.dart           # QR code + adresse à copier
    history_screen.dart           # Historique complet des transactions
    settings_screen.dart          # Sécurité, réseau RPC, danger zone
    pin_setup_screen.dart         # Configuration / changement du PIN
    lock_screen.dart              # Écran de déverrouillage (PIN ou biométrie)
  widgets/
    balance_card.dart             # Carte du solde avec actualisation
    transaction_tile.dart         # Ligne d'historique de transaction
    mnemonic_grid.dart            # Grille de la phrase mnémonique
    pin_pad.dart                  # Pavé numérique de saisie PIN
test/
  wallet_service_test.dart        # Tests unitaires du service wallet
  security_provider_test.dart     # Tests unitaires PIN, biométrie, session
```

## Fonctionnalités implémentées

### Gestion du portefeuille
- Génération BIP-39 (12 mots) avec étape de confirmation obligatoire
- Import par phrase mnémonique avec validation stricte
- Dérivation déterministe de la clé privée Ethereum depuis la seed BIP-39
- Stockage chiffré (FlutterSecureStorage : Keychain iOS / Keystore Android)

### Blockchain
- Solde ETH en temps réel via un nœud RPC public (configurable)
- Envoi de transactions ETH avec estimation des frais gas
- Historique local des transactions (envoi/réception, statut)
- URL RPC personnalisable depuis les paramètres
- Marché Binance spot complet (toutes les paires disponibles) avec actualisation
- Actions Achat / Vente depuis l'app (redirection vers Binance)

### Sécurité
- Code PIN (6 chiffres) avec hash SHA-256 en stockage sécurisé
- Déverrouillage biométrique (empreinte / Face ID) via local_auth
- Verrouillage automatique après 5 minutes d'inactivité en arrière-plan
- Verrouillage manuel depuis les paramètres
- Effacement sécurisé de toutes les données depuis les paramètres

### Navigation
- Redirection intelligente au démarrage (onboarding / lock / home)
- Observer du cycle de vie de l'application pour le verrouillage de session

## Installation

1. Installer Flutter et vérifier l'environnement :
   ```
   flutter doctor
   ```

2. Installer les dépendances :
   ```
   flutter pub get
   ```

3. Lancer l'application :
   ```
   flutter run
   ```

4. Exécuter les tests :
   ```
   flutter test
   ```

## Déploiement Web (mycryptosafe.fr)

L'application est déployée sur **https://mycryptosafe.fr** via GitHub Pages et
un workflow CI automatique (`.github/workflows/deploy_pages.yml`).

### GitHub Pages (domaine principal)

- À chaque push sur `main`, le workflow :
  1. installe Flutter (stable, en cache),
  2. active la plateforme Web (`flutter create . --platforms web`),
  3. génère l'application avec
     `flutter build web --release --base-href / --dart-define=PWA_URL=https://mycryptosafe.fr/`,
  4. ajoute un fichier `CNAME` contenant `mycryptosafe.fr` dans `build/web`,
  5. publie l'artefact via `actions/deploy-pages`.
- Le domaine personnalisé `mycryptosafe.fr` doit être configuré dans les
  paramètres du dépôt GitHub (Settings → Pages → Custom domain).
- La redirection SPA est gérée via `404.html` qui renvoie vers `/index.html`.

### Netlify (miroir optionnel)

- La configuration `netlify.toml` + `scripts/netlify_build.sh` permet de
  déployer l'app en miroir sur Netlify si besoin.
- Le build passe `--dart-define=PWA_URL=https://mycryptosafe.fr/` pour que le
  bouton PWA pointe toujours vers le domaine principal.

### Bouton « Progressive Web App »

- Il lit l'URL via `--dart-define=PWA_URL=https://mycryptosafe.fr/`.
- Si `PWA_URL` est absent/invalide : en Web, le bouton cible l'origine courante
  (`/`) ; hors Web, le fallback est `https://mycryptosafe.fr/`.

## Configuration Android requise

Dans `android/app/build.gradle`, s'assurer que :
- `minSdkVersion` >= 23 (requis par `local_auth` pour la biométrie)

## Dépendances clés

| Paquet | Usage |
|---|---|
| `provider` | Gestion d'état global (ChangeNotifier) |
| `flutter_secure_storage` | Stockage chiffré des secrets |
| `bip39` | Génération et validation des phrases mnémoniques |
| `web3dart` | Client Ethereum RPC |
| `http` | Transport HTTP pour web3dart |
| `qr_flutter` | Affichage QR code de l'adresse |
| `local_auth` | Authentification biométrique |
| `shared_preferences` | Préférences non-sensibles (URL RPC) |
| `crypto` | Hachage SHA-256 du PIN |

## Note sur la dérivation de clé

La clé privée Ethereum est dérivée des 32 premiers octets de la seed BIP-39
(64 octets). Cette dérivation est déterministe et reproductible depuis la phrase
mnémonique, mais n'est pas conforme BIP-44. Une dérivation complète
(chemin `m/44'/60'/0'/0/0`) peut être ajoutée ultérieurement avec une
bibliothèque BIP-32 dédiée.
