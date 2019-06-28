@ECHO OFF

PUSHD "%~dp0\..\.."

SET TAG_UBUNTU_1404=dtbosh-ubuntu14.04
SET TAG_UBUNTU_1604=dtbosh-ubuntu16.04
SET PROJECT=dtbosh_linux
SET DOCKER_COMPOSE_OPTS=--project-name %PROJECT% --file integration\linux\docker-compose.yml

ECHO Starting up services...
docker-compose %DOCKER_COMPOSE_OPTS% up --detach --build || GOTO :error

ECHO Building Ubuntu 14.04 image for tests...
docker build --tag %TAG_UBUNTU_1404% --file integration\linux\Dockerfile.Test.Ubuntu14.04 . || GOTO :error

ECHO Building Ubuntu 16.04 image for tests...
docker build --tag %TAG_UBUNTU_1604% --file integration\linux\Dockerfile.Test.Ubuntu16.04 . || GOTO :error

ECHO Running tests for Ubuntu 14.04...
docker run --rm --env "DEPLOYMENT_MOCK_URL=http://apimock:8080" --network %PROJECT%_default %TAG_UBUNTU_1404% || GOTO :error

ECHO Running tests for Ubuntu 16.04...
docker run --rm --env "DEPLOYMENT_MOCK_URL=http://apimock:8080" --network %PROJECT%_default %TAG_UBUNTU_1604% || GOTO :error

ECHO Shutting down services...
docker-compose %DOCKER_COMPOSE_OPTS% down

POPD

GOTO :EOF

:error
ECHO Shutting down services...
docker-compose %DOCKER_COMPOSE_OPTS% down

POPD

ECHO Task failed
EXIT /b %errorlevel%


docker-compose --project-name asd --file integration\linux\docker-compose.yml up --detach