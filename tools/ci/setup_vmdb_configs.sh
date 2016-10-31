echo "1" > REGION
cp certs/v2_key.dev certs/v2_key
cp config/database.pg.yml config/database.yml
cp config/cable.yml.sample config/cable.yml
psql -c "CREATE USER root SUPERUSER PASSWORD 'smartvm';" -U postgres
