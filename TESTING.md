# Integration Tests for Dynatrace OneAgent BOSH Release

**WARNING**: The current state of the test setup requires root permissions.
We recommend to only run them in a seperate VM, which does not host anything else.

## Requirements
* Ubuntu 14/Ubuntu 16
* Ruby 2.1+

## Bootstrap test environment
* Clone this repository to $repodir

```bash
curl -sSL https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm
rvm install 2.1
gem install bundler
cd $repodir
bundle
```

## Run tests
* Set needed environment variables:
```bash
export DT_TENANT=sometenantid
export DT_API_TOKEN=someapitoken
```
* (optional) If not running against a live.dynatrace.com tenant, set API URL as well:
```bash
export DT_API_URL=http://your.api.url
```

* Actually run the tests:
```bash
cd $repodir
sudo -s
rspec
```
