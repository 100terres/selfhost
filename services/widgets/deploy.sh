#!/bin/bash

# init
rm -f ./nginx/active_service.conf
cp ./active_service.conf.template ./nginx/active_service.conf
docker compose up -d

PROXY_SERVICE="widgets-proxy"
SERVICES=("widgets-server-a" "widgets-server-b")

for SERVICE in "${SERVICES[@]}"; do
    CONTAINER_ID=$(docker compose ps -q $SERVICE)

    if [ -z "$CONTAINER_ID" ]; then
        echo "⚠️ $SERVICE is not running. Deploying fresh..."
        # Skip straight to pulling and starting if the container doesn't exist yet
    else
        # Get the exact IMAGE ID the container currently running
        RUNNING_IMAGE_ID=$(docker inspect --format='{{.Image}}' "$CONTAINER_ID" | cut -d':' -f2)
        echo "Running Image ID: $RUNNING_IMAGE_ID"

        # Use the Image ID to find its corresponding Local Repo Digest
        # (This avoids relying on the mutable tag name)
        # LOCAL_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$RUNNING_IMAGE_ID" 2>/dev/null | cut -d'@' -f2 | cut -d':' -f2)
        # echo "Local Digest:     $LOCAL_DIGEST"
    fi

    # Get service image tag
    IMAGE_TAG=$(docker compose config --format json | jq -r ".services.\"$SERVICE\".image")

    # Fetch the remote registry digest
    REMOTE_DIGEST=$(docker manifest inspect --insecure $IMAGE_TAG | jq -r '.config.digest | split(":")[1]')
    echo "Remote Digest:    $REMOTE_DIGEST"

    # 6. Compare the active running digest with the registry digest
    if [ -n "$CONTAINER_ID" ] && [ "$RUNNING_IMAGE_ID" == "$REMOTE_DIGEST" ]; then
        echo "Active container for $SERVICE matches the registry. Skipping deployment."
        continue
    fi

    echo "Rolling out update for $SERVICE"

    # Stop serving service
    sed -i "s/server $SERVICE/# server $SERVICE/" ./nginx/active_service.conf
    docker compose exec $PROXY_SERVICE nginx -s reload

    # Update service
    docker compose pull $SERVICE
    docker compose stop $SERVICE
    docker compose up -d $SERVICE

    # Wait for the health check loop
    while true; do
        STATUS=$(docker inspect --format='{{.State.Health.Status}}' $(docker compose ps -q $SERVICE))
        if [ "$STATUS" == "healthy" ]; then
            echo "$SERVICE is healthy!"
            break
        elif [ "$STATUS" == "unhealthy" ]; then
            echo "ERROR: $SERVICE health check failed!"
            exit 1
        else
            sleep 3
        fi
    done

    # Re-enable the service in Nginx using sed
    sed -i "s/# server $SERVICE/server $SERVICE/" ./nginx/active_service.conf
    docker compose exec $PROXY_SERVICE nginx -s reload

    echo "$SERVICE update complete!"
done
