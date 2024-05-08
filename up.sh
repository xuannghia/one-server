#!/bin/bash

IMAGE=xuannghia/whoami-curl
SERVICE_NAME=webapp
ENV_FILE=./.env.example
DOMAIN=webapp.localhost

COUNT_FILE=".${SERVICE_NAME}_count"

if [ ! -f $COUNT_FILE ]; then
  echo 0 > $COUNT_FILE
fi

COUNT=$(cat $COUNT_FILE)
NEXT=$(($COUNT + 1))

NAME="${SERVICE_NAME}_$NEXT"

# This command will run INSIDE the container
HEALTH_CMD="curl --fail http://127.0.0.1:80/health"

# START NEW CONTAINER
echo "Starting new container..."
docker run \
 --detach \
 --name $NAME \
 --env-file $ENV_FILE \
 --restart unless-stopped \
 --network traefik-proxy \
 --label "traefik.enable=true" \
 --label "traefik.http.routers.$NAME.rule=Host(\`$DOMAIN\`)" \
 --label "traefik.http.routers.$NAME.entrypoints=web" \
 --health-cmd="$HEALTH_CMD" \
 --health-interval=10s \
 --health-start-interval=1s \
 --health-start-period=5s \
 $IMAGE

CONTAINER_ID=$(docker ps -qf name=$NAME)
echo "Container ID: $CONTAINER_ID"

# INCREMENT COUNT
echo $NEXT > $COUNT_FILE

# WAIT FOR HEALTHY
HEALTHY=0
while [ $HEALTHY -eq 0 ]; do
  HEALTH=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_ID)
  echo "Health: $HEALTH"
  if [ $HEALTH == "healthy" ]; then
    HEALTHY=1
  else
    sleep 1
  fi
done

# STOP OLD RUNNING CONTAINER
echo "Stopping old running container..."
OLD_CONTAINER_ID=$(docker ps -qf name=$SERVICE_NAME | head -n2 | tail -n1)
if [ $CONTAINER_ID != $OLD_CONTAINER_ID ]; then
  docker stop $OLD_CONTAINER_ID
fi

# REMOVE OLD CONTAINERS, KEEP 3 NEWEST
echo "Cleaning up old containers..."
KEEP=3
CONTAINER_COUNT=$(docker ps -aqf name=$SERVICE_NAME | wc -l)
if [ $CONTAINER_COUNT -gt $KEEP ]; then
  TAIL_FROM=$(($CONTAINER_COUNT - $KEEP))
  OLD_CONTAINERS=$(docker ps -aqf name=$SERVICE_NAME | tail -n $TAIL_FROM)
  docker rm $OLD_CONTAINERS
fi
