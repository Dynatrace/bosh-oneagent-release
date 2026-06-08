#!/usr/bin/env bash

cd "$(dirname "$0")/../.."

tag_ubuntu_2204="dtbosh-ubuntu22.04"
tag_ubuntu_2404="dtbosh-ubuntu24.04"
project="dtbosh_linux"
docker_compose_opts="--project-name $project --file integration/linux/docker-compose.yml"

echo "Starting up services..."
if ! docker-compose $docker_compose_opts up --detach --build ; then
    echo "Task failed"
    exit 1
fi

function fail {
    echo "Shutting down services..."
    docker-compose $docker_compose_opts down

    echo "Task failed"
    exit 1
}

echo "Building Ubuntu 22.04 image for tests..."
docker build --tag "$tag_ubuntu_2204" --file integration/linux/Dockerfile.Test.Ubuntu22.04 . || fail

echo "Building Ubuntu 24.04 image for tests..."
docker build --tag "$tag_ubuntu_2404" --file integration/linux/Dockerfile.Test.Ubuntu24.04 . || fail

echo "Running tests for Ubuntu 22.04..."
docker run --rm --env "DEPLOYMENT_MOCK_URL=http://apimock:8080" --network "${project}_default" "$tag_ubuntu_2204" || fail

echo "Running tests for Ubuntu 24.04..."
docker run --rm --env "DEPLOYMENT_MOCK_URL=http://apimock:8080" --network "${project}_default" "$tag_ubuntu_2404" || fail

echo "Shutting down services..."
docker-compose $docker_compose_opts down
