# Bot de Trading Binance avec LLM

Ce projet est un bot de trading automatisé pour Binance qui utilise l'intelligence artificielle pour prendre des décisions de trading. Il surveille les nouveaux listings et analyse leur croissance pour identifier les opportunités de trading.

## Fonctionnalités

- Connexion à l'API Binance
- Surveillance des nouveaux listings
- Analyse de la croissance et du volume
- Intégration avec un LLM pour l'analyse des opportunités
- Mode Live et Dry Run
- Interface utilisateur moderne avec Tailwind CSS
- Suivi des performances et des métriques
- Gestion des risques avec des limites d'investissement

## Prérequis

- Ruby 3.2 ou supérieur
- Rails 7.2
- PostgreSQL
- Redis
- Compte Binance avec API activée

## Installation

1. Clonez le repository :
```bash
git clone [URL_DU_REPO]
cd [NOM_DU_DOSSIER]
```

2. Installez les dépendances :
```bash
bundle install
```

3. Configurez la base de données :
```bash
rails db:create db:migrate
```

4. Configurez les variables d'environnement :
```bash
cp .env.example .env
# Éditez .env avec vos clés API Binance et autres configurations
```

5. Démarrez Redis :
```bash
redis-server
```

6. Démarrez Sidekiq :
```bash
bundle exec sidekiq
```

7. Démarrez le serveur Rails :
```bash
rails server
```

## Configuration

1. Accédez à l'interface web à l'adresse `http://localhost:3000/trading`
2. Créez une nouvelle configuration de trading avec vos clés API Binance
3. Configurez les paramètres de trading :
   - Mode (Live/Dry Run)
   - Intervalle de vérification
   - Taux de croissance minimum
   - Investissement maximum par trade

## Utilisation

1. Une fois la configuration créée, cliquez sur "Démarrer le Trading"
2. Le bot commencera à surveiller les nouveaux listings
3. Les opportunités et les trades seront affichés dans l'interface
4. Les métriques de performance sont mises à jour en temps réel

## Sécurité

- Les clés API sont chiffrées dans la base de données
- Le mode Dry Run permet de tester sans risque
- Les limites d'investissement protègent contre les pertes excessives

## Contribution

Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou à soumettre une pull request.

## Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.
