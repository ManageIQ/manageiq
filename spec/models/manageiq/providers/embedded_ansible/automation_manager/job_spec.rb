describe ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job do
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
    let(:playbook)              { FactoryBot.create(:embedded_playbook, :configuration_script_source => ansible_script_source) }
    let(:manager)               { FactoryBot.create(:embedded_automation_manager_ansible, :provider) }

    let(:machine_credential)    { FactoryBot.create(:ansible_machine_credential, :manager_ref => "1", :resource => manager) }
    let(:cloud_credential)      { FactoryBot.create(:ansible_cloud_credential,   :manager_ref => "2", :resource => manager) }
    let(:network_credential)    { FactoryBot.create(:ansible_network_credential, :manager_ref => "3", :resource => manager) }
    let(:vault_credential)      { FactoryBot.create(:ansible_vault_credential,   :manager_ref => "4", :resource => manager) }

    let(:raw_stdout_json) do
      [
        {"stdout" => "A stdout from the job"},
        {"stdout" => "Errmahgerd... ANSIBLER"},
        {"stdout" => "And another one"}
      ]
    end

    let(:template) { FactoryBot.create(:embedded_ansible_configuration_script, :manager => manager, :parent => playbook) }

    describe "job operations" do
      describe ".create_job" do
        context "template is persisted" do
          it "creates a job" do
            job = described_class.create_job(template, {})
            expect(job.class).to                 eq(described_class)
            expect(job.name).to                  eq(template.name)
            expect(job.ems_ref).to               eq(job.miq_task.id.to_s)
            expect(job.job_template).to          eq(template)
            expect(job.status).to                eq(job.miq_task.state)
            expect(job.ext_management_system).to eq(manager)
            expect(job.retireable?).to           be false
          end
        end

        context "template is temporary" do
          let(:template) { FactoryBot.build(:embedded_ansible_configuration_script, :manager => manager, :parent => playbook) }

          it "creates a job" do
            job = described_class.create_job(template, {})
            expect(job.job_template).to be_nil
          end
        end

        it "catches errors from provider" do
          expect(template).to receive(:run).and_raise("bad request")

          expect do
            described_class.create_job(template, {})
          end.to raise_error(MiqException::MiqOrchestrationProvisionError)
        end

        context "options have extra_vars" do
          let(:template) do
            FactoryBot.build(:embedded_ansible_configuration_script,
                             :manager     => manager,
                             :parent      => playbook,
                             :variables   => {"Var1" => "v1", "VAR2" => "v2"},
                             :survey_spec => {"spec" => [{"default" => "v3", "variable" => "var3", "type" => "text"}]})
          end

          it "updates the extra_vars with original keys" do
            described_class.create_job(template, :extra_vars => {"var1" => "n1", "var2" => "n2", "VAR3" => "n3"})
          end
        end
      end

      context "#refresh_ems" do
        subject { described_class.create_job(template, {}) }

        it "syncs the job with the provider" do
          subject.refresh_ems

          expect(subject).to have_attributes(
            :ems_ref     => subject.miq_task.id.to_s,
            :status      => subject.miq_task.state,
            :start_time  => subject.miq_task.started_on,
            :finish_time => nil,
            :verbosity   => nil # TODO:  Implement this as an job options, right?
          )
          subject.reload
          expect(subject.ems_ref).to eq(subject.miq_task.id.to_s)
          expect(subject.status).to  eq(subject.miq_task.state)

          # TODO/FIXME:  This needs to be implemented.
          #
          # The following are implemented in AnsibleTower::Job but not here:
          #
          #   - update_parameters
          #   - update_credentials
          #   - update_plays
          #
          # expect(subject.parameters.first).to have_attributes(:name => "param1", :value => "val1")
          # expect(subject.authentications).to match_array([machine_credential, vault_credential, cloud_credential, network_credential])
          # expect(subject.job_plays.first).to have_attributes(
          #   :start_time        => a_value_within(1.second).of(the_raw_plays.first.created),
          #   :finish_time       => a_value_within(1.second).of(the_raw_plays.last.created),
          #   :resource_status   => "successful",
          #   :resource_category => "job_play",
          #   :name              => "play1"
          # )
          # expect(subject.job_plays.last).to have_attributes(
          #   :start_time        => a_value_within(1.second).of(the_raw_plays.last.created),
          #   :finish_time       => a_value_within(1.second).of(the_raw_job.finished),
          #   :resource_status   => "failed",
          #   :resource_category => "job_play",
          #   :name              => "play2"
          # )
        end

        # TODO:  This is should be irrelevant now, right?
        # it "catches errors from provider" do
        #   expect(connection.api.jobs).to receive(:find).and_raise("bad request")
        #   expect { subject.refresh_ems }.to raise_error(MiqException::MiqOrchestrationUpdateError)
        # end
      end
    end

    describe "job status" do
      subject { described_class.create_job(template, {}) }

      context "#raw_status and #raw_exists" do
        it "gets the stack status" do
          rstatus = subject.raw_status
          expect(rstatus).to have_attributes(:status => "Pre_execute", :reason => nil)

          expect(subject.raw_exists?).to be_truthy
        end
      end
    end

    # TODO:  Punting for now need some more time to get this tested properly,
    #        but don't have the current mental capacity to figure the right way
    #        to set this up in a time crunch.

    # describe "#raw_stdout" do
    #   subject { described_class.create_job(template, {}) }

    #   it "gets the standard output of the job" do
    #     expect(subject.raw_stdout("html")).to eq("<html><body>job stdout</body></html>")
    #   end

    #   it "catches errors from provider" do
    #     expect(connection.api.jobs).to receive(:find).and_raise("bad happened")
    #     expect { subject.raw_stdout("html") }.to raise_error(MiqException::MiqOrchestrationStatusError)
    #   end
    # end
    #
    # describe "#raw_stdout_via_worker" do
    #   before do
    #     EvmSpecHelper.create_guid_miq_server_zone
    #     allow(described_class).to receive(:find).and_return(job)

    #     allow(MiqTask).to receive(:wait_for_taskid) do
    #       request = MiqQueue.find_by(:class_name => described_class.name)
    #       request.update_attributes(:state => MiqQueue::STATE_DEQUEUE)
    #       request.delivered(*request.deliver)
    #     end
    #   end

    #  it "gets stdout from the job" do
    #    expect(job).to receive(:raw_stdout).and_return("A stdout from the job")
    #    taskid = job.raw_stdout_via_worker("user")
    #    MiqTask.wait_for_taskid(taskid)
    #    expect(MiqTask.find(taskid)).to have_attributes(
    #      :task_results => "A stdout from the job",
    #      :status       => "Ok"
    #    )
    #  end

    #   it "returns the error message" do
    #     expect(job).to receive(:raw_stdout).and_throw("Failed to get stdout from the job")
    #     taskid = job.raw_stdout_via_worker("user")
    #     MiqTask.wait_for_taskid(taskid)
    #     expect(MiqTask.find(taskid).message).to include("Failed to get stdout from the job")
    #     expect(MiqTask.find(taskid).status).to eq("Error")
    #   end
    # end
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
end
