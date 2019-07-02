# Integration Tests for Dynatrace OneAgent BOSH Release

There are scripts available that run the tests under Docker containers trying to simulate Linux and Windows environments.

## Requirements
* Docker
* docker-compose

## Linux integration tests

The tests run in both Ubuntu 14.04 and Ubuntu 16.04 images and can be executed with,

Linux: `$ integration/linux/run-tests.sh`
Windows: `> integration/linux/run-tests.bat`

## Windows integration tests

The tests run in both Windows Server 2016 and Windows Server 2019 and can be executed with,

`> integration/windows/run-tests.bat`
