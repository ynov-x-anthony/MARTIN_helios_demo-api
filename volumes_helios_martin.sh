#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

db_name=demo-db
api_name=demo-api
network=demo-quest5
volume=demo_pgdata
api_port=${API_PORT:-8080}
base_url="http://127.0.0.1:$api_port"
db_created=0
api_created=0
network_created=0

for name in "$db_name" "$api_name"; do
  if docker container inspect "$name" >/dev/null 2>&1; then
    printf '%s existe déjà, arrêt pour le préserver.\n' "$name" >&2
    exit 1
  fi
done

if docker network inspect "$network" >/dev/null 2>&1; then
  printf '%s existe déjà, arrêt pour le préserver.\n' "$network" >&2
  exit 1
fi

cleanup() {
  if (( api_created )); then
    docker rm -f "$api_name" >/dev/null 2>&1 || true
  fi
  if (( db_created )); then
    docker rm -f "$db_name" >/dev/null 2>&1 || true
  fi
  if (( network_created )); then
    docker network rm "$network" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

wait_for_db() {
  for ((attempt = 0; attempt < 30; attempt++)); do
    if docker exec "$db_name" pg_isready -U demo -d demo >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  docker logs "$db_name"
  return 1
}

start_db() {
  docker run -d \
    --name "$db_name" \
    --network "$network" \
    -v "$volume:/var/lib/postgresql/data" \
    -v "$PWD/db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro" \
    -e POSTGRES_USER=demo \
    -e POSTGRES_PASSWORD=demo \
    -e POSTGRES_DB=demo \
    postgres:16-alpine >/dev/null
  db_created=1
}

start_api() {
  docker run -d \
    --name "$api_name" \
    --network "$network" \
    -p "127.0.0.1:$api_port:3000" \
    -e PGHOST="$db_name" \
    -e PGUSER=demo \
    -e PGPASSWORD=demo \
    -e PGDATABASE=demo \
    demo-api:1.0 >/dev/null
  api_created=1
}

wait_for_api() {
  for ((attempt = 0; attempt < 30; attempt++)); do
    if curl --fail --silent "$base_url/ready" >/dev/null; then
      return 0
    fi
    sleep 1
  done
  docker logs "$api_name"
  return 1
}

docker build -t demo-api:1.0 ./api
docker volume create "$volume"
docker network create "$network" >/dev/null
network_created=1

start_db
wait_for_db
start_api
wait_for_api

created=$(curl --fail --silent --show-error \
  -X POST \
  -H 'content-type: application/json' \
  -d '{"name":"Casquette Démo","price_cents":1200}' \
  "$base_url/products")
printf '%s\n' "$created"
product_id=$(printf '%s' "$created" | sed -nE 's/.*"id":([0-9]+).*/\1/p')
if [[ -z "$product_id" ]]; then
  printf 'Impossible de récupérer l’identifiant du produit.\n' >&2
  exit 1
fi

printf 'Avant recréation de la base :\n'
before=$(curl --fail --silent --show-error "$base_url/products")
printf '%s\n' "$before"
if ! grep -Fq "\"id\":$product_id," <<<"$before"; then
  printf 'Le produit ajouté est absent avant la recréation.\n' >&2
  exit 1
fi

docker rm -f "$api_name"
api_created=0
docker rm -f "$db_name"
db_created=0
start_db
wait_for_db
start_api
wait_for_api

docker volume ls | grep -F "$volume"
printf 'Après recréation de la base :\n'
after=$(curl --fail --silent --show-error "$base_url/products")
printf '%s\n' "$after"
if ! grep -Fq "\"id\":$product_id," <<<"$after"; then
  printf 'Le produit ajouté n’a pas survécu à la recréation.\n' >&2
  exit 1
fi

# docker volume rm demo_pgdata
