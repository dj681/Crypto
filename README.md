# My Crypto Safe

Application mobile Flutter de portefeuille crypto sécurisé.

## Architecture

```
lib/
  main.dart                       # Point d'entrée : MultiProvider, NavigatorKey, cycle de vie
  models/
    wallet.dart                   # Modèle immuable du portefeuille (sans secrets)
    tx_record.dart                # Enregistrement local de transaction
    market_ticker.dart            # Données d'un ticker (crypto ou actif réel)
  services/
    wallet_service.dart           # BIP-39, dérivation de clé, stockage chiffré
    blockchain_service.dart       # Client web3dart : balance, envoi, gas
    security_service.dart         # PIN (SHA-256), biométrie (local_auth)
    market_service.dart           # API marché applicative (backend) + fallback
  providers/
    wallet_provider.dart          # État global du portefeuille + historique
    blockchain_provider.dart      # Solde ETH, envoi de transactions
    security_provider.dart        # Session : verrouillage, PIN, biométrie
    market_provider.dart          # État des marchés crypto et actifs réels
  screens/
    splash_screen.dart            # Chargement initial (wallet/session)
    onboarding_screen.dart        # Choix : créer ou importer
    wallet_create_screen.dart     # Génération BIP-39 + confirmation des mots
    wallet_import_screen.dart     # Import par phrase mnémonique
    home_screen.dart              # Interface principale (Accueil, Trader, Récompense, Découvrir, Convertir)
    market_screen.dart            # Vue Trader avec choix Crypto / Actifs réels + actions achat/vente
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
bin/
  backend_server.dart             # Backend HTTP (health, marchés applicatifs, overrides manuels)
```

## Fonctionnalités implémentées

### Gestion du portefeuille
- Génération d'une phrase de récupération à 4 mots avec étape de confirmation obligatoire
- Import par phrase mnémonique avec validation stricte
- Dérivation déterministe de la clé privée Ethereum depuis la phrase de récupération (BIP-39 legacy ou PBKDF2-SHA512 pour 4 mots)
- Stockage chiffré (FlutterSecureStorage : Keychain iOS / Keystore Android)

### Blockchain
- Solde ETH en temps réel via un nœud RPC public (configurable)
- Envoi de transactions ETH avec estimation des frais gas
- Historique local des transactions (envoi/réception, statut)
- URL RPC personnalisable depuis les paramètres
- Marché crypto en temps réel via backend applicatif (source Binance)
- Marché des actifs réels en temps réel via backend applicatif (or, argent, Brent, WTI, platine)
- Possibilité d'override manuel des prix côté backend
- Sélecteur de marché dans l'onglet Trader (crypto-monnaies numériques / actifs réels)

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

### Backend (recommandé)

Lancer le backend local :

```
dart run bin/backend_server.dart
```

Par défaut il écoute sur `http://localhost:8080` (modifiable via `PORT`).

Pour faire utiliser ce backend par l'app Flutter :

```
flutter run --dart-define=BACKEND_URL=http://localhost:8080
```

#### Endpoints marché backend

- `GET /api/market/crypto` : liste des tickers crypto en temps réel.
- `GET /api/market/real-assets` : liste des actifs réels en temps réel.
- `GET /api/market/overrides` : liste des overrides manuels actifs.
- `PUT /api/market/overrides` : crée/modifie un override manuel.
- `DELETE /api/market/overrides/{market}/{symbol}` : supprime un override.

Exemple d'override manuel :

```
curl -X PUT http://localhost:8080/api/market/overrides \
  -H "Content-Type: application/json" \
  -d '{
    "market":"real-assets",
    "symbol":"XAUUSD",
    "baseAsset":"XAU",
    "quoteAsset":"USD",
    "lastPrice":2450.12,
    "priceChangePercent":1.23,
    "quoteVolume":1000000,
    "name":"Or",
    "unit":"oz"
  }'
```

4. Exécuter les tests :
   ```
   flutter test
   ```

### Compte administrateur

Le panneau d'administration permet à un compte désigné de consulter toutes les recharges de cartes cadeaux soumises par les utilisateurs.

**Configuration requise (build-time) :**

| `--dart-define` | Rôle |
|---|---|
| `ADMIN_PHRASE` | Phrase de récupération de l'administrateur (4 mots ou BIP-39, ne pas commiter) |
| `ADMIN_PIN` | Code PIN à 6 chiffres pré-configuré pour le compte admin (facultatif) |
| `ADMIN_TOKEN` | Token Bearer que l'app envoie au backend pour accéder aux endpoints admin |

**Configuration backend (runtime) :**

| Variable d'environnement | Rôle |
|---|---|
| `ADMIN_TOKEN` | Même valeur que le `--dart-define` côté app — protège les endpoints admin |
| `ABYTONE` | Secret de dépôt — authentifie les notifications de dépôt entrant (`POST /api/deposit`) |

Exemple de build sécurisé :

```bash
flutter build web --release \
  --base-href / \
  --dart-define=BACKEND_URL=https://api.mycryptosafe.fr \
  --dart-define=ADMIN_PHRASE="mot1 mot2 mot3 mot4" \
  --dart-define=ADMIN_PIN=123456 \
  --dart-define=ADMIN_TOKEN=my-secret-token
```

Exemple de démarrage backend sécurisé :

```bash
ADMIN_TOKEN=my-secret-token ABYTONE=my-deposit-secret dart run bin/backend_server.dart
```

**Endpoints admin (protégés par `Authorization: Bearer <ADMIN_TOKEN>`) :**

| Méthode | Endpoint | Description |
|---|---|---|
| `GET` | `/api/gift-cards/recharge` | Liste toutes les recharges |
| `DELETE` | `/api/gift-cards/recharge/:id` | Supprime une recharge (droit à l'effacement RGPD) |
| `GET` | `/api/admin/audit-log` | Journal des accès admin (horodaté) |
| `GET` | `/api/deposit` | Liste tous les dépôts enregistrés |
| `DELETE` | `/api/deposit/:id` | Supprime un dépôt (droit à l'effacement RGPD) |

**Endpoint dépôt (protégé par `Authorization: Bearer <ABYTONE>`) :**

| Méthode | Endpoint | Description |
|---|---|---|
| `POST` | `/api/deposit` | Enregistre une notification de dépôt entrant |

Corps de la requête `POST /api/deposit` :

```json
{
  "txHash": "0xabc123...",
  "amount": 100.0,
  "currency": "USDT",
  "walletAddress": "0x9aEB4A4d8d888bF8Df8b1F6af6B065DaA516ce50",
  "network": "BEP20",
  "userId": "user-id-optionnel"
}
```

> ⚠️ **Sécurité** : ne jamais committer `ADMIN_PHRASE`, `ADMIN_PIN`, `ADMIN_TOKEN` ou `ABYTONE` dans le dépôt.  
> Utiliser les secrets GitHub Actions (`Settings → Secrets and variables → Actions → Secrets`) pour les passer au workflow CI.  
> La valeur de `ADMIN_TOKEN` doit être **identique** entre le build Flutter (`--dart-define=ADMIN_TOKEN=...`) et la variable d'environnement du backend (`ADMIN_TOKEN=...`). Un décalage entre les deux empêche toute authentification admin.

## Déploiement Web (mycryptosafe.fr)

L'application est déployée sur **https://mycryptosafe.fr** via GitHub Pages et
un workflow CI automatique (`.github/workflows/deploy_pages.yml`).

### GitHub Pages (domaine principal)

- À chaque push sur `main`, le workflow :
  1. installe Flutter (stable, en cache),
  2. active la plateforme Web (`flutter create . --platforms web`),
  3. génère l'application avec
     `flutter build web --release --base-href / --dart-define=PWA_URL=https://mycryptosafe.fr/`,
     en ajoutant `--dart-define=BACKEND_URL=<url>` si la variable
     `BACKEND_URL` est définie dans les paramètres du dépôt
     (Settings → Secrets and variables → Actions → **Variables**),
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
- Pour activer le backend sur Netlify, définir la variable d'environnement
  `BACKEND_URL` dans le dashboard Netlify (Site settings → Environment variables).

### Variable `BACKEND_URL`

| Plateforme | Comment définir `BACKEND_URL` |
|---|---|
| **GitHub Pages** | Dépôt → Settings → Secrets and variables → Actions → Variables → `BACKEND_URL` |
| **Netlify** | Site settings → Environment variables → `BACKEND_URL` |
| **Local** | `flutter run --dart-define=BACKEND_URL=http://localhost:8080` |

Si la variable est absente ou vide, l'app utilise directement l'API CoinGecko
(crypto) et Stooq (actifs réels) sans proxy backend.

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

La clé privée Ethereum est dérivée des 32 premiers octets d'une seed de 64 octets.
Pour les phrases BIP-39 legacy, cette seed vient de `mnemonicToSeed`.
Pour les nouvelles phrases de 4 mots, la seed est dérivée via PBKDF2-HMAC-SHA512.
Le format 4 mots (~44 bits d'entropie) réduit fortement la robustesse par rapport à BIP-39 12 mots (~128 bits) et constitue un compromis UX/sécurité.
Ce format est nettement plus vulnérable au brute-force et ne doit pas être considéré au même niveau de sécurité qu'une phrase BIP-39 standard.
Cette dérivation est déterministe et reproductible depuis la phrase, mais n'est pas conforme BIP-44. Une dérivation complète
(chemin `m/44'/60'/0'/0/0`) peut être ajoutée ultérieurement avec une
bibliothèque BIP-32 dédiée.
