#!/usr/bin/env bash

cd "$(dirname "$0")/../.."

tag_ubuntu_1404="dtbosh-ubuntu14.04"
tag_ubuntu_1604="dtbosh-ubuntu16.04"
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

    echo "Error: Task failed"
    exit 1
}

echo "Building Ubuntu 14.04 image for tests..."
docker build --tag "$tag_ubuntu_1404" --file integration/linux/Dockerfile.Test.Ubuntu14.04 . || fail

echo "Building Ubuntu 16.04 image for tests..."
docker build --tag "$tag_ubuntu_1604" --file integration/linux/Dockerfile.Test.Ubuntu16.04 . || fail

echo "Running tests for Ubuntu 14.04..."
docker run --rm --env "DEPLOYMENT_MOCK_URL=http://apimock:8080" --network "${project}_default" "$tag_ubuntu_1404" || fail

echo "Running tests for Ubuntu 16.04..."
docker run --rm --env "DEPLOYMENT_MOCK_URL=http://apimock:8080" --network "${project}_default" "$tag_ubuntu_1604" || fail

echo "Shutting down services..."
docker-compose $docker_compose_opts down

function demo {
    result=0

    while true; do
        result=1
        break
    done

    echo $result
}

function demo_duplicate {
    result=0
 
    while true; do
        result=1
        break
    done

    echo $result

}

demo
demo_duplicate
