#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

db_name=demo-db
api_name=demo-api
front_network=demo_front
back_network=demo_back
test_image=nicolaka/netshoot
api_port=${API_PORT:-8080}
base_url="http://127.0.0.1:$api_port"
db_created=0
api_created=0
front_created=0
back_created=0

for name in "$db_name" "$api_name"; do
  if docker container inspect "$name" >/dev/null 2>&1; then
    printf '%s existe déjà, arrêt pour le préserver.\n' "$name" >&2
    exit 1
  fi
done

for network in "$front_network" "$back_network"; do
  if docker network inspect "$network" >/dev/null 2>&1; then
    printf '%s existe déjà, arrêt pour le préserver.\n' "$network" >&2
    exit 1
  fi
done

cleanup() {
  if (( api_created )); then
    docker rm -fv "$api_name" >/dev/null 2>&1 || true
  fi
  if (( db_created )); then
    docker rm -fv "$db_name" >/dev/null 2>&1 || true
  fi
  if (( front_created )); then
    docker network rm "$front_network" >/dev/null 2>&1 || true
  fi
  if (( back_created )); then
    docker network rm "$back_network" >/dev/null 2>&1 || true
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

show_ips() {
  docker inspect -f '{{range $name, $net := .NetworkSettings.Networks}}{{printf "%s %s\n" $name $net.IPAddress}}{{end}}' "$1"
}

docker build -t demo-api:1.0 ./api
docker network create "$front_network" >/dev/null
front_created=1
docker network create "$back_network" >/dev/null
back_created=1

db_created=1
docker run -d \
  --name "$db_name" \
  --network "$back_network" \
  -v "$PWD/db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro" \
  -e POSTGRES_USER=demo \
  -e POSTGRES_PASSWORD=demo \
  -e POSTGRES_DB=demo \
  postgres:16-alpine >/dev/null
wait_for_db

api_created=1
docker run -d \
  --name "$api_name" \
  --network "$back_network" \
  -p "127.0.0.1:$api_port:3000" \
  -e PGHOST="$db_name" \
  -e PGUSER=demo \
  -e PGPASSWORD=demo \
  -e PGDATABASE=demo \
  demo-api:1.0 >/dev/null
docker network connect "$front_network" "$api_name"
wait_for_api

printf 'Résolution DNS depuis demo-api :\n'
docker exec "$api_name" getent hosts "$db_name"

if ! docker image inspect "$test_image" >/dev/null 2>&1; then
  docker pull "$test_image"
fi

printf 'Test depuis demo_front uniquement :\n'
if docker run --rm --network "$front_network" "$test_image" nc -zv -w 3 "$db_name" 5432; then
  printf 'Erreur : demo-db est joignable depuis demo_front.\n' >&2
  exit 1
else
  printf 'demo-db est inaccessible depuis demo_front, comme attendu.\n'
fi

printf 'Adresses IPv4 de demo-db :\n'
show_ips "$db_name"
printf 'Adresses IPv4 de demo-api :\n'
show_ips "$api_name"

printf 'Produits :\n'
curl --fail --silent --show-error "$base_url/products"
printf '\n'
