# env-e2e per-project config (sourced bash — see the env-e2e package README).
E2E_COMPOSE_FILES=(compose.e2e.yml)
E2E_RUNNER_SERVICE="e2e"
E2E_WAIT_TIMEOUT=120
# Seed exercises the db through the compose project ($E2E_COMPOSE is exported
# by the lifecycle script: `docker compose -p <proj> -f <files...>`).
E2E_SEED_COMMAND='$E2E_COMPOSE exec -T db psql -U postgres -d app -c "CREATE TABLE IF NOT EXISTS smoke(id int PRIMARY KEY); INSERT INTO smoke VALUES (1) ON CONFLICT DO NOTHING;"'
