[![CircleCI](https://circleci.com/gh/Dynatrace/bosh-oneagent-release.svg?style=svg)](https://circleci.com/gh/Dynatrace/bosh-oneagent-release)

# Dynatrace OneAgent BOSH Release

This is a [BOSH](http://bosh.io/) release for [Dynatrace](https://www.dynatrace.com/).

This release installs Dynatrace OneAgent on BOSH managed VMs. It is intended to be used as BOSH addon for rolling out Dynatrace OneAgent to all VMs, including Linux and Windows Diego cells.

## Usage

To use this BOSH release, first upload it to your BOSH. You can either build the release on your own or use a pre-built one from the Github repository releases.

```
bosh -e <YOUR_BOSH_DIRECTOR> upload-release /path/to/built/dynatrace-oneagent.tgz
```

Update the bosh-director's runtime-config. You will need to modify the `runtime-config-dynatrace.yml` to suit your needs, e.g. limit the addon to specific BOSH deployments. You will find your credentials in your Dynatrace UI.


```
bosh update-runtime-config runtime-config-dynatrace.yml
```

Run bosh deploy to install OneAgent on the VMs.

## Limitations
All releases since 0.3.6 upwards are packaged via bosh2. This means you can't upload them to your director with the bosh1 cli.
Since v2.0 of the Cloud Foundry Ops Manager, bosh2 is the default and is simply called with 'bosh'. If you use a version prior to that, bosh2 should be available besides the default bosh1. You can call it with the 'bosh2' command.
Replace the commands above respectively

Releases since v1.0.5 also require BOSH Director v263 or greater.

## License

Licensed under the MIT License. See the [LICENSE](https://github.com/dynatrace-innovationlab/bosh-oneagent-release/blob/master/LICENSE) file for details.
