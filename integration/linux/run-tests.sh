#!/usr/bin/env bash

cd "$(dirname "$0")/../.."

tag_ubuntu_1404="dtbosh-ubuntu14.04"
tag_ubuntu_2604="dtbosh-ubuntu26.04"
project="dtbosh_linux"
docker_compose_opts="--project-name $project --file integration/linux/docker-compose.yml"

echo "Starting up services..."
if ! docker-compose $docker_compose_opts up --detach --build; then
	echo "Task failed"
	exit 1
fi

function fail {
	echo "Shutting down services..."
	docker-compose $docker_compose_opts down

	echo "Task failed"
	exit 1
}

echo "Building Ubuntu 14.04 image for tests..."
docker build --tag "$tag_ubuntu_1404" --file integration/linux/Dockerfile.Test.Ubuntu14.04 . || fail

echo "Building Ubuntu 26.04 image for tests..."
docker build --tag "$tag_ubuntu_2604" --file integration/linux/Dockerfile.Test.Ubuntu26.04 . || fail

echo "Running tests for Ubuntu 14.04..."
docker run --rm --env "DEPLOYMENT_MOCK_URL=http://apimock:8080" --network "${project}_default" "$tag_ubuntu_1404" || fail

echo "Running tests for Ubuntu 26.04..."
docker run --rm --env "DEPLOYMENT_MOCK_URL=http://apimock:8080" --network "${project}_default" "$tag_ubuntu_2604" || fail

echo "Shutting down services..."
docker-compose $docker_compose_opts down
