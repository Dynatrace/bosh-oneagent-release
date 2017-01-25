# Change me
VERSION=0.1

bosh deployment dynatrace-oneagent-deployment-manifest.yml
bosh -n delete deployment dynatrace-oneagent
bosh -n delete release dynatrace-oneagent
rm -rf dev_releases
bosh create release --with-tarball --version $VERSION
bosh upload release
bosh -n deploy
