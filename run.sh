bosh deployment dynatrace-oneagent-deployment-manifest.yml
bosh -n delete deployment dynatrace-oneagent
bosh -n delete release dynatrace-oneagent
bosh create release
bosh upload release
bosh -n deploy
