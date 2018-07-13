require 'json'
require 'rspec'
require 'rspec/bash'
require 'bosh/template/test'
require 'pathname'
require 'fileutils'


describe 'dynatrace release' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '../..')) }
  let(:stubbed_env) { Rspec::Bash::StubbedEnv.new(Rspec::Bash::StubbedEnv::BASH_STUB) }

  describe 'dynatrace-oneagent job' do
    let(:job) { release.job('dynatrace-oneagent') }

    describe 'pre-start' do
      let(:template) { job.template('bin/pre-start') }

      describe 'render' do
        let(:manifest) do
          {
            'dynatrace' => {
              'environmentid' => 'environmentid',
              'apitoken' => 'apitoken'
            }
          }
        end

        it 'render' do
          script = template.render(manifest)

          expect(script).to match('^export DOWNLOADURL=""$')
          expect(script).to match('^export PROXY=""$')
          expect(script).to match('^export ENV_ID="environmentid"$')
          expect(script).to match('^export API_TOKEN="apitoken"$')
          expect(script).to match('^export API_URL=""$')
          expect(script).to match('^export SSL_MODE=""$')
          expect(script).to match('^export APP_LOG_CONTENT_ACCESS="1"$')
          expect(script).to match('^export HOST_GROUP=""$')
          expect(script).to match('^export HOST_TAGS=""$')
          expect(script).to match('^export INFRA_ONLY=""$')
        end
      end

      describe 'install base dir #1' do
        describe 'test directory exists' do
          let(:manifest) do
            {
              'dynatrace' => {
                'environmentid' => 'environmentid',
                'apitoken' => 'apitoken'
              }
            }
          end
          it 'test' do
            script = template.render(manifest)
            stdout, stderr, status = stubbed_env.execute_inline(script)
            expect(stdout).to match("Not enough disk space available on /var/vcap/data!")
            expect(status.exitstatus).to eq 1
          end
        end
        describe 'create install base dir' do
          it 'make path', :install => true do
            FileUtils.mkpath('/var/vcap/data')
          end
        end
      end

      describe 'custom urls' do
        describe 'downloadurl' do
          let(:manifest) do
            {
              'dynatrace' => {
                'downloadurl' => 'downloadurl',
                'environmentid' => '',
                'apitoken' => ''
              }
            }
          end
          it 'exec' do
            script = template.render(manifest)
            stdout, stderr, status = stubbed_env.execute_inline(script)
            expect(stdout).to match(/Downloading agent installer from downloadurl/)
            expect(stdout).to match(/Dynatrace agent download failed, retrying in /)
            expect(stdout).to match(/ERROR: Downloading agent installer failed!/)
            expect(status.exitstatus).to eq 1
          end
        end
        describe 'apiurl' do
          let(:manifest) do
            {
              'dynatrace' => {
                'apiurl' => 'apiurl',
                'environmentid' => 'na',
                'apitoken' => 'na'
              }
            }
          end
          it 'exec' do
            script = template.render(manifest)
            stdout, stderr, status = stubbed_env.execute_inline(script)
            expect(stdout).to include("Downloading agent installer from apiurl/v1/deployment/installer/agent/unix/default/latest?Api-Token=na")
            expect(stdout).to match(/ERROR: Downloading agent installer failed!/)
            expect(status.exitstatus).to eq 1
          end
        end
      end

      describe 'invalid configuration' do
        describe 'no environmentid' do
          let(:manifest) do
            {
              'dynatrace' => {
                'environmentid' => '',
                'apitoken' => 'apitoken'
              }
            }
          end
          it 'exec' do
            script = template.render(manifest)
            stdout, stderr, status = stubbed_env.execute_inline(script)
            expect(status.exitstatus).to eq 1
            expect(stdout).to match(/Please set environment ID and API token for Dynatrace OneAgent./)
          end
        end
        describe 'no apitoken' do
          let(:manifest) do
            {
              'dynatrace' => {
                'environmentid' => 'environmentid',
                'apitoken' => ''
              }
            }
          end
          it 'exec' do
            script = template.render(manifest)
            stdout, stderr, status = stubbed_env.execute_inline(script)
            expect(status.exitstatus).to eq 1
            expect(stdout).to match(/Please set environment ID and API token for Dynatrace OneAgent./)
          end
        end
        describe 'no environmentid,apitoken' do
          let(:manifest) do
            {
              'dynatrace' => {
                'environmentid' => '',
                'apitoken' => ''
              }
            }
          end
          it 'exec' do
            script = template.render(manifest)
            stdout, stderr, status = stubbed_env.execute_inline(script)
            expect(status.exitstatus).to eq 1
            expect(stdout).to match(/Please set environment ID and API token for Dynatrace OneAgent./)
          end
        end
      end

      describe 'install' do
        let(:manifest) do
          {
            'dynatrace' => {
              'environmentid' => ENV["DT_TENANT"],
              'apitoken' => ENV["DT_API_TOKEN"],
              'apiurl' => ENV["DT_API_URL"]
            }
          }
        end
        it 'parameter test' do
          expect(ENV).to have_key("DT_TENANT")
          expect(ENV).to have_key("DT_API_TOKEN")
          expect(ENV).to have_key("DT_API_URL")
        end
        it 'exec', :install => true do
          script = template.render(manifest)
          stdout, stderr, status = stubbed_env.execute_inline(script)
          expect(stdout).to match(/Installation finished/)
          expect(stdout).to_not match(/Error/)
          expect(status.exitstatus).to eq 0
          expect(FileTest.exist?('/var/vcap/sys/run/dynatrace-oneagent/dynatrace-watchdog.pid')).to be true
        end
      end

    end

    describe 'stop-oneagent.sh', :monit => true do
      let(:template) { job.template('bin/stop-oneagent.sh') }
      let(:manifest) {}
      it 'exec' do
        script = template.render(manifest)
        stdout, stderr, status = stubbed_env.execute_inline(script)
        expect(status.exitstatus).to eq 0
      end
    end


    describe 'start-oneagent.sh', :monit => true do
      let(:template) { job.template('bin/start-oneagent.sh') }
      let(:manifest) {}
      it 'exec' do
        script = template.render(manifest)
        stdout, stderr, status = stubbed_env.execute_inline(script)
        expect(status.exitstatus).to eq 0
      end
    end


    describe 'drain' do
      let(:template) { job.template('bin/drain') }
      describe 'exec', :uninstall => true do
        let(:manifest) {}
        it 'exec' do
          script = template.render(manifest)
          stdout, stderr, status = stubbed_env.execute_inline(script)
          expect(status.exitstatus).to eq 0
          expect(stdout).to eq("0\n")
        end
      end

      describe 'install base dir #2' do
        describe 'remove install base dir' do
          it 'remove path', :uninstall => true do
            FileUtils.remove_entry_secure('/var/vcap/data')
          end
        end
      end
    end


  end
end
