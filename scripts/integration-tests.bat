@ECHO OFF

PUSHD "%~dp0\.."

SET TAG_UBUNTU_1404=bosh-oneagent-release-test-ubuntu-14.04
SET TAG_UBUNTU_1604=bosh-oneagent-release-test-ubuntu-16.04

ECHO Starting up services...
docker-compose up --detach --build || GOTO :error

ECHO Building Ubuntu 14.04 image for tests...
docker build --tag %TAG_UBUNTU_1404% --file Dockerfile-Test-Ubuntu14.04 . || GOTO :error

ECHO Building Ubuntu 16.04 image for tests...
docker build --tag %TAG_UBUNTU_1604% --file Dockerfile-Test-Ubuntu16.04 . || GOTO :error

ECHO Running tests for Ubuntu 14.04...
docker run --rm --env "DEPLOYMENT_MOCK_URL=http://localhost:8080" --network "container:dynatrace-deployment-api-mock" ^
           %TAG_UBUNTU_1404% || GOTO :error

ECHO Running tests for Ubuntu 16.04...
docker run --rm --env "DEPLOYMENT_MOCK_URL=http://localhost:8080" --network "container:dynatrace-deployment-api-mock" ^
           %TAG_UBUNTU_1604% || GOTO :error

ECHO Shutting down services...
docker-compose down

POPD

GOTO :EOF

:error
ECHO Shutting down services...
docker-compose down

POPD

ECHO Task failed
EXIT /b %errorlevel%
