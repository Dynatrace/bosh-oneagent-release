# Dynatrace OneAgent BOSH Release

This is a [BOSH](http://bosh.io/) release for [Dynatrace](https://www.dynatrace.com/).

This release installs Dynatrace OneAgent on BOSH managed VMs. It is intended to be used as BOSH addon for rolling out Dynatrace OneAgent all VMs, including Linux and Windows Diego cells. 

## Usage

To use this BOSH release, first upload it to your BOSH. You can either build the release on your own or use a pre-built one from the Github repository releases.

```
bosh target <YOUR_BOSH_HOST>
bosh upload release path/to/built/dynatrace-oneagent.tgz
```

Update the bosh-director's runtime-config. You will need to modify the `runtime-config-dynatrace.yml` to suit your needs, e.g. limit the addon to specific bosh deployments. You will find your credentials in your Dyntrace UI.


```
bosh update runtime-config runtime-config-dynatrace.yml
```

Run bosh deploy to install OneAgent on the VMs.

## License

Licensed under the MIT License. See the [LICENSE](https://github.com/dynatrace-innovationlab/bosh-oneagent-release/blob/master/LICENSE) file for details.
