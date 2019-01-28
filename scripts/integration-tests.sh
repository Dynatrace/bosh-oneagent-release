#!/usr/bin/env bash

cd "$(dirname "$0")/.."

TAG_UBUNTU_1404=bosh-oneagent-release-test-ubuntu-14.04
TAG_UBUNTU_1604=bosh-oneagent-release-test-ubuntu-16.04

echo Starting up services...
if ! docker-compose up --detach --build ; then
    echo Task failed
    exit 1
fi

function fail {
    echo Shutting down services...
    docker-compose down

    echo Task failed
    exit 1
}

echo Building Ubuntu 14.04 image for tests...
docker build --tag $TAG_UBUNTU_1404 --file Dockerfile-Test-Ubuntu14.04 . || fail

echo Building Ubuntu 16.04 image for tests...
docker build --tag $TAG_UBUNTU_1604 --file Dockerfile-Test-Ubuntu16.04 . || fail

echo Running tests for Ubuntu 14.04...
docker run --rm --env "DEPLOYMENT_MOCK_URL=http://deployment-api-mock:8080" --network "bosh-oneagent-release_testnet" $TAG_UBUNTU_1404 || fail

echo Running tests for Ubuntu 16.04...
docker run --rm --env "DEPLOYMENT_MOCK_URL=http://deployment-api-mock:8080" --network "bosh-oneagent-release_testnet" $TAG_UBUNTU_1604 || fail

echo Shutting down services...
docker-compose down
