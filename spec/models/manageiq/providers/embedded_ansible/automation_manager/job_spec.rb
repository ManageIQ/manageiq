RSpec.describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job do
  let(:job) { FactoryBot.create(:embedded_ansible_job) }

  before do
    region = MiqRegion.seed
    allow(MiqRegion).to receive(:my_region).and_return(region)
  end

  context "when embedded_ansible role is enabled" do
    before do
      EvmSpecHelper.assign_embedded_ansible_role

      allow_any_instance_of(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScriptSource).to receive(:checkout_git_repository)
    end

    let(:ansible_script_source) { FactoryBot.create(:embedded_ansible_configuration_script_source, :manager => manager) }
    let(:playbook)              { FactoryBot.create(:embedded_playbook, :configuration_script_source => ansible_script_source, :manager => manager) }
    let(:manager)               { FactoryBot.create(:embedded_automation_manager_ansible, :provider) }

    let(:machine_credential)    { FactoryBot.create(:ansible_machine_credential, :manager_ref => "1", :resource => manager) }
    let(:cloud_credential)      { FactoryBot.create(:ansible_cloud_credential,   :manager_ref => "2", :resource => manager) }
    let(:network_credential)    { FactoryBot.create(:ansible_network_credential, :manager_ref => "3", :resource => manager) }
    let(:vault_credential)      { FactoryBot.create(:ansible_vault_credential,   :manager_ref => "4", :resource => manager) }

    let(:job_options) do
      {
        :credential         => machine_credential.id,
        :cloud_credential   => cloud_credential.id,
        :network_credential => network_credential.id,
        :vault_credential   => vault_credential.id
      }
    end

    describe "job operations" do
      describe ".create_job" do
        it "creates a job" do
          job = described_class.create_job(playbook, job_options)
          expect(job.class).to                 eq(described_class)
          expect(job.name).to                  eq(playbook.name)
          expect(job.ems_ref).to               eq(job.miq_task.id.to_s)
          expect(job.playbook).to              eq(playbook)
          expect(job.status).to                eq(job.miq_task.state)
          expect(job.ext_management_system).to eq(manager)
          expect(job.retireable?).to           be false
        end

        it "catches errors from provider" do
          expect(playbook).to receive(:run).and_raise("bad request")

          expect do
            described_class.create_job(playbook, {})
          end.to raise_error(MiqException::MiqOrchestrationProvisionError)
        end
      end

      context "#refresh_ems" do
        subject { described_class.create_job(playbook, job_options) }

        before { Timecop.freeze }
        after  { Timecop.return }

        let(:the_raw_plays) do
          [
            {
              "id"         => 1,
              "event"      => "playbook_on_play_start",
              "failed"     => false,
              "created"    => Time.current,
              "event_data" => {"play" => "play1"}
            },
            {
              "id"         => 2,
              "event"      => "some_other_event",
              "failed"     => false,
              "created"    => Time.current + 5,
              "event_data" => {"stdout" => "foo"}
            },
            {
              "id"         => 3,
              "event"      => "playbook_on_play_start",
              "failed"     => true,
              "created"    => Time.current + 10,
              "event_data" => {"play" => "play2"}
            }
          ]
        end

        it "syncs the job with the provider" do
          fake_finish_time = the_raw_plays.last["created"] + 15
          allow(subject).to receive(:finish_time).and_return(fake_finish_time)
          expect(subject).to receive(:raw_stdout_json).and_return(the_raw_plays)
          subject.refresh_ems

          expect(subject).to have_attributes(
            :ems_ref     => subject.miq_task.id.to_s,
            :status      => subject.miq_task.state,
            :start_time  => subject.miq_task.started_on,
            :finish_time => fake_finish_time,
            :verbosity   => 0
          )
          subject.reload
          expect(subject.ems_ref).to eq(subject.miq_task.id.to_s)
          expect(subject.status).to  eq(subject.miq_task.state)

          expect(subject.authentications).to match_array([machine_credential, vault_credential, cloud_credential, network_credential])

          expect(subject.job_plays.first).to have_attributes(
            :start_time        => a_value_within(1.second).of(the_raw_plays.first["created"]),
            :finish_time       => a_value_within(1.second).of(the_raw_plays.last["created"]),
            :resource_status   => "successful",
            :resource_category => "job_play",
            :name              => "play1"
          )
          expect(subject.job_plays.last).to have_attributes(
            :start_time        => a_value_within(1.second).of(the_raw_plays.last["created"]),
            :finish_time       => a_value_within(1.second).of(fake_finish_time),
            :resource_status   => "failed",
            :resource_category => "job_play",
            :name              => "play2"
          )

          # TODO/FIXME:  This needs to be implemented.
          #
          # The following are implemented in AnsibleTower::Job but not here:
          #
          #   - update_parameters
          #
          # expect(subject.parameters.first).to have_attributes(:name => "param1", :value => "val1")
          #
        end
      end
    end

    describe "job status" do
      subject { described_class.create_job(playbook, {}) }

      context "#raw_status and #raw_exists" do
        it "gets the stack status" do
          rstatus = subject.raw_status
          expect(rstatus).to have_attributes(:status => "Pre_execute", :reason => nil)

          expect(subject.raw_exists?).to be_truthy
        end
      end
    end

    describe "#raw_stdout_via_worker" do
      before do
        EvmSpecHelper.create_guid_miq_server_zone
        allow(described_class).to receive(:find).and_return(job)

        allow(MiqTask).to receive(:wait_for_taskid) do
          request = MiqQueue.find_by(:class_name => described_class.name)
          request.update(:state => MiqQueue::STATE_DEQUEUE)
          request.delivered(*request.deliver)
        end
      end

      it "gets stdout from the job" do
        expect(job).to receive(:raw_stdout).and_return("A stdout from the job")
        taskid = job.raw_stdout_via_worker("user")
        MiqTask.wait_for_taskid(taskid)
        expect(MiqTask.find(taskid)).to have_attributes(
          :task_results => "A stdout from the job",
          :status       => "Ok"
        )
      end

      it "returns the error message" do
        expect(job).to receive(:raw_stdout).and_throw("Failed to get stdout from the job")
        taskid = job.raw_stdout_via_worker("user")
        MiqTask.wait_for_taskid(taskid)
        expect(MiqTask.find(taskid).message).to include("Failed to get stdout from the job")
        expect(MiqTask.find(taskid).status).to eq("Error")
      end
    end
  end

  context "when embedded_ansible role is disabled" do
    describe "#raw_stdout_via_worker" do
      let(:role_enabled) { false }

      it "returns an error message" do
        taskid = job.raw_stdout_via_worker("user")
        expect(MiqTask.find(taskid)).to have_attributes(
          :message => "Cannot get standard output of this playbook because the embedded Ansible role is not enabled",
          :status  => "Error"
        )
      end
    end
  end

  describe "#raw_stdout" do
    let(:ansible_runner_stdout) do
      [
        {"stdout" => "Line 1"},              # no color
        {"stdout" => "\e[0;32mLine 2\e[0m"}, # green
        {"stdout" => "\e[0;31mLine 3\e[0m"}, # red
      ]
    end

    context "when miq_task present" do
      before do
        job.miq_task = FactoryGirl.create(:miq_task, :context_data => {:ansible_runner_stdout => ansible_runner_stdout})
      end

      it "json" do
        expect(job.raw_stdout("json")).to eq ansible_runner_stdout
      end

      it "txt" do
        expect(job.raw_stdout("txt")).to eq "Line 1\n\e[0;32mLine 2\e[0m\n\e[0;31mLine 3\e[0m"
      end

      it "html" do
        expect(job.raw_stdout("html")).to include <<~EOHTML
          <div class='term-container'>
          Line 1
          <span class='term-fg32'>Line 2</span>
          <span class='term-fg31'>Line 3</span>
          </div>
        EOHTML
      end

      it "nil" do
        expect(job.raw_stdout).to eq "Line 1\n\e[0;32mLine 2\e[0m\n\e[0;31mLine 3\e[0m"
      end
    end

    shared_examples_for "ansible runner stdout not valid in miq_task" do
      it "json" do
        expect(job.raw_stdout("json")).to eq([])
      end

      it "txt" do
        expect(job.raw_stdout("txt")).to eq ""
      end

      it "html" do
        expect(job.raw_stdout("html")).to include <<~EOHTML
          <div class='term-container'>
          No output available
          </div>
        EOHTML
      end

      it "nil" do
        expect(job.raw_stdout).to eq ""
      end
    end

    context "when miq_task is missing" do
      before { job.miq_task = nil }

      it_behaves_like "ansible runner stdout not valid in miq_task"
    end

    context "when miq_task present, but without context data" do
      before { job.miq_task = FactoryGirl.create(:miq_task) }

      it_behaves_like "ansible runner stdout not valid in miq_task"
    end

    context "when miq_task present with context_data, but missing ansible_runner_stdout" do
      before { job.miq_task = FactoryGirl.create(:miq_task, :context_data => {}) }

      it_behaves_like "ansible runner stdout not valid in miq_task"
    end
  end
end
