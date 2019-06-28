require 'json'
require 'net/http'
require 'rspec'
require 'rspec/bash'
require 'bosh/template/test'
require 'pathname'
require 'fileutils'
require 'tempfile'

def run_script(script)
  file = Tempfile.new(['inlinescript', '.ps1'])
  begin
    file.write(script)
    file.close

    output = `powershell #{file.path.gsub('/', '\\')} 2>&1`
    status = $?

    return [output, status]
  ensure
    file.unlink
  end
end

describe 'dynatrace windows release', :windows do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '../..')) }
  let(:stubbed_env) { Rspec::Bash::StubbedEnv.new(Rspec::Bash::StubbedEnv::BASH_STUB) }

  let(:release_version) { Bosh::Template::Test::InstanceSpec.new().to_h().merge({'release' => { 'version' => '123' }}) }

  describe 'dynatrace-oneagent-windows job' do
    let(:job) { release.job('dynatrace-oneagent-windows') }

    describe 'pre-start' do
      let(:template) { job.template('bin/pre-start.ps1') }

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
          script = template.render(manifest, spec: release_version)

          expect(script).to match('^\\$cfgDownloadUrl = ""$')
          expect(script).to match('^\\$cfgProxy = ""$')
          expect(script).to match('^\\$cfgEnvironmentId = "environmentid"$')
          expect(script).to match('^\\$cfgApiToken = "apitoken"$')
          expect(script).to match('^\\$cfgApiUrl = ""$')
          expect(script).to match('^\\$cfgSslMode = ""$')
          expect(script).to match('^\\$cfgHostGroup = ""$')
          expect(script).to match('^\\$cfgHostTags = ""$')
          expect(script).to match('^\\$cfgHostProps = " BOSHReleaseVersion=123"$')
          expect(script).to match('^\\$cfgInfraOnly = "0"$')
        end
      end

      describe 'install base dir #1' do
        describe 'create log dir' do
          it 'make path', :install => true do
            # Creating it to avoid scripts print errors when logging.
            FileUtils.mkpath('C:\\var\\vcap\\sys\\log\\dynatrace-oneagent-windows')
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
            script = template.render(manifest, spec: release_version)
            output, status = run_script(script)
            expect(output).to match(/Downloading Dynatrace agent from downloadurl/)
            expect(output).to match(/Dynatrace agent download failed, retrying in /)
            expect(output).to match(/ERROR Downloading agent installer failed!/)
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
            script = template.render(manifest, spec: release_version)
            output, status = run_script(script)
            expect(output).to include("Downloading Dynatrace agent from apiurl/v1/deployment/installer/agent/windows/default/latest?Api-Token=na")
            expect(output).to match(/ERROR Downloading agent installer failed!/)
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
            script = template.render(manifest, spec: release_version)
            output, status = run_script(script)
            expect(output).to match(/Invalid configuration: Please provide environment ID and API token!/)
            expect(status.exitstatus).to eq 1
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
            script = template.render(manifest, spec: release_version)
            output, status = run_script(script)
            expect(output).to match(/Invalid configuration: Please provide environment ID and API token!/)
            expect(status.exitstatus).to eq 1
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
            script = template.render(manifest, spec: release_version)
            output, status = run_script(script)
            expect(output).to match(/Invalid configuration: Please provide environment ID and API token!/)
            expect(status.exitstatus).to eq 1
          end
        end
      end

      describe 'install' do
        let(:manifest) do
          {
            'dynatrace' => {
              'environmentid' => 'testtenant',
              'apitoken' => 'testapitoken',
              'apiurl' => ENV["DEPLOYMENT_MOCK_URL"],
            }
          }
        end
        it 'parameter test' do
          expect(ENV).to have_key("DEPLOYMENT_MOCK_URL")
        end
        it 'prepares deployment api' do
          uri = URI.join(ENV["DEPLOYMENT_MOCK_URL"], '/register')
          response = Net::HTTP.post_form(uri, {
            'platform' => 'windows',
            'installerType' => 'default',
            'apiToken' => 'testapitoken',
          })
          expect(response).to be_a(Net::HTTPSuccess)
        end
        it 'exec', :install => true do
          script = template.render(manifest, spec: release_version)
          output, status = run_script(script)
          expect(output).to match(/Installation done/)
          expect(output).to_not match(/ERROR/)
          expect(status.exitstatus).to eq 0
        end
      end
    end

    describe 'start.ps1', :monit => true do
      let(:template) { job.template('bin/start.ps1') }
      let(:manifest) {}
      it 'exec' do
        # This sentinel file is used by start.ps1 to know when to stop. Usually created by stop.ps1.
        FileUtils.touch('C:\\var\\vcap\\data\\dt_tmp\\exit')
        script = template.render(manifest, spec: release_version)
        output, status = run_script(script)
        expect(status.exitstatus).to eq 0
      end
    end

    describe 'stop.ps1', :monit => true do
      let(:template) { job.template('bin/stop.ps1') }
      let(:manifest) {}
      it 'exec' do
        # The stop.ps1 script waits until the service is deleted, so we deleted manually:
        `sc stop "Dynatrace OneAgent"`
        `sc delete "Dynatrace OneAgent"`

        # The script also creates this file to signal start.ps1 to stop, who also deletes it to indicate
        # that has finished.
        #
        # To simulate start.ps1 behavior we add some delay and then delete the file.
        Thread.new {
          sleep(10)
          FileUtils.rm('C:\\var\\vcap\\data\\dt_tmp\\exit')
        }

        script = template.render(manifest)
        output, status = run_script(script)
        expect(status.exitstatus).to eq 0
      end
    end

    describe 'drain' do
      let(:template) { job.template('bin/drain.ps1') }
      describe 'exec', :uninstall => true do
        let(:manifest) {}
        it 'exec' do
          script = template.render(manifest, spec: release_version)
          output, status = run_script(script)
          expect(status.exitstatus).to eq 0
          expect(output).to eq("0\n")
        end
      end

      describe 'install base dir #2' do
        describe 'remove install base dir' do
          it 'remove path', :uninstall => true do
            FileUtils.remove_entry_secure('C:\\var\\vcap\\data')
          end
        end
      end
    end

  end
end
