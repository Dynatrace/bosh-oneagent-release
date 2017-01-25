# Dynatrace OneAgent BOSH Release

This is a [BOSH](http://bosh.io/) release for [Dynatrace](https://www.dynatrace.com/).

This release installs Dynatrace OneAgent on BOSH managed VMs. It is intended to be used as BOSH addon to the BOSH director.

## Usage

To use this BOSH release, first upload it to your BOSH. You can either build the release on your own or use a pre-built one from the Github repository releases.

```
bosh target <YOUR_BOSH_HOST>
bosh upload release path/to/built/dynatrace-oneagent.tgz
```

Update the bosh-director's runtime-config. You will need to modify the `runtime-config-dynatrace.yml` to suit your needs.

Change `version` of the release and replace the `downloadurl` property with your installer URL.

```
# replace version and downloadurl
vi runtime-config-dynatrace.yml

bosh update runtime-config runtime-config-dynatrace.yml
```

Re-deploy your vms and bosh will automatically install OneAgent on the VMs.

## License

Licensed under the MIT License. See the [LICENSE](https://github.com/dynatrace-innovationlab/bosh-oneagent-release/blob/master/LICENSE) file for details.
