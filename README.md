# demo-api

Mini API catalogue avec Node.js, Express et PostgreSQL, utilisée pour les quêtes Docker.

## Prérequis

- Docker Engine avec Compose v2 (`docker compose version`)
- `curl`

## Démarrer

Copier la configuration et créer le fichier local du secret PostgreSQL :

```sh
cp .env.example .env
mkdir -p secrets
printf '%s\n' 'demo-password' > secrets/db_password.txt
chmod 644 secrets/db_password.txt
```

Lancer les services :

```sh
docker compose up -d --build
docker compose ps
```

L'API est disponible sur `http://localhost:8080` et Adminer sur `http://localhost:8081`. Dans Adminer, choisir PostgreSQL, serveur `db`, puis utiliser l'utilisateur et la base définis dans `.env` ainsi que le mot de passe du fichier `secrets/db_password.txt`.

## API

| Méthode | Route | Effet |
|---|---|---|
| `GET` | `/` | Infos de l'application et version |
| `GET` | `/version` | Version courante |
| `GET` | `/health` | Vérifie que l'API répond |
| `GET` | `/ready` | Vérifie la connexion PostgreSQL |
| `GET` | `/products` | Liste les produits |
| `POST` | `/products` | Crée un produit avec `name` et `price_cents` |

Exemple :

```sh
curl -s http://localhost:8080/products
curl -s -X POST http://localhost:8080/products \
  -H 'Content-Type: application/json' \
  -d '{"name":"Gourde","price_cents":900}'
```

Testé avec `docker compose up -d --build`, puis `docker compose down` et un nouveau `docker compose up -d --build`. La Gourde reste présente après le redémarrage.

```text
$ docker compose ps
NAME                 IMAGE                COMMAND                  SERVICE   CREATED          STATUS                    PORTS
demo-api-adminer-1   adminer:4            "entrypoint.sh docke…"   adminer   13 seconds ago   Up 12 seconds             0.0.0.0:8081->8080/tcp, [::]:8081->8080/tcp
demo-api-api-1       demo-api-api         "docker-entrypoint.s…"   api       13 seconds ago   Up 6 seconds (healthy)    0.0.0.0:8080->3000/tcp, [::]:8080->3000/tcp
demo-api-db-1        postgres:16-alpine   "docker-entrypoint.s…"   db        13 seconds ago   Up 12 seconds (healthy)   5432/tcp
```

Les données PostgreSQL restent dans le volume `pgdata` après `docker compose down`. Pour repartir de zéro et supprimer les données :

```sh
docker compose down -v
```

`.env` et `secrets/` sont des fichiers locaux ignorés par Git. Seul `.env.example` est versionné.
