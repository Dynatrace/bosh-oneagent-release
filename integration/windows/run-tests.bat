@ECHO OFF

PUSHD "%~dp0\..\.."

SET TAG_WS16=dtbosh-ws16
SET TAG_WS19=dtbosh-ws19
SET PROJECT=dtbosh_windows
SET DOCKER_COMPOSE_OPTS=--project-name %PROJECT% --file integration\windows\docker-compose.yml

ECHO Starting up services...
docker-compose %DOCKER_COMPOSE_OPTS% up --detach --build || GOTO :error

ECHO Building Windows Server 2016 image for tests...
docker build --tag %TAG_WS16% --file integration\windows\Dockerfile.Test.WS16 . || GOTO :error

ECHO Building Windows Server 2019 image for tests...
docker build --tag %TAG_WS19% --file integration\windows\Dockerfile.Test.WS19 . || GOTO :error

ECHO Running tests for Windows Server 2016...
docker run --rm --env "DEPLOYMENT_MOCK_URL=http://apimock:8080" --network %PROJECT%_default %TAG_WS16% || GOTO :error

ECHO Running tests for Windows Server 2019...
docker run --rm --env "DEPLOYMENT_MOCK_URL=http://apimock:8080" --network %PROJECT%_default %TAG_WS19% || GOTO :error

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
