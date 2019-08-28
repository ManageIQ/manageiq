RSpec.describe InfraConversionJob, :v2v do
  let(:user)                  { FactoryBot.create(:user_with_group) }
  let(:zone)                  { FactoryBot.create(:zone) }

  let(:ems_vmware)            { FactoryBot.create(:ems_vmware, :zone => zone) }
  let(:ems_cluster_vmware)    { FactoryBot.create(:ems_cluster, :ext_management_system => ems_vmware) }
  let(:host_vmware)           { FactoryBot.create(:host, :ext_management_system => ems_vmware, :ems_cluster => ems_cluster_vmware) }
  let(:lan_vmware)            { FactoryBot.create(:lan) }
  let(:network_vmware)        { FactoryBot.create(:network, :ipaddress => nil) }
  let(:nic_vmware)            { FactoryBot.create(:guest_device_nic, :lan => lan_vmware, :network => network_vmware) }
  let(:hardware_vmware)       { FactoryBot.create(:hardware, :nics => [nic_vmware], :networks => [network_vmware]) }
  let(:vm_vmware) do
    FactoryBot.create(:vm_vmware,
                      :ext_management_system => ems_vmware,
                      :ems_cluster => ems_cluster_vmware,
                      :host => host_vmware,
                      :hardware => hardware_vmware,
                      :evm_owner => user)
  end

  let(:ems_redhat)            { FactoryBot.create(:ems_redhat, :zone => zone) }
  let(:ems_cluster_redhat)    { FactoryBot.create(:ems_cluster, :ext_management_system => ems_redhat) }
  let(:host_redhat)           { FactoryBot.create(:host, :ext_management_system => ems_redhat, :ems_cluster => ems_cluster_redhat) }
  let(:vm_redhat)             { FactoryBot.create(:vm_vmware, :ext_management_system => ems_redhat, :ems_cluster => ems_cluster_redhat, :host => host_redhat, :evm_owner => user) }

  let(:embedded_ansible_auth) { FactoryBot.create(:embedded_ansible_credential) }
  let(:embedded_ansible_catalog_item_options) do
    {
      :name                        => 'Test Migration Playbook',
      :description                 => 'Migration Playbook for testing purpose',
      :config_info                 => {
        :provision => {
          :credential_id         => embedded_ansible_auth.id,
          :hosts                 => 'localhost',
        },
      }
    }
  end
  let(:embedded_ansible_service_template)     { ServiceTemplateAnsiblePlaybook.create_catalog_item(embedded_ansible_catalog_item_options, nil) }
  let(:embedded_ansible_service_request)      { FactoryBot.create(:service_template_provision_request, :source => embedded_ansible_service_template, :approval_state => 'approved', :requester => user) }

  let(:transformation_mapping) do
    FactoryBot.create(:transformation_mapping).tap do |tm|
      FactoryBot.create(:transformation_mapping_item,
                        :source                 => ems_cluster_vmware,
                        :destination            => ems_cluster_redhat,
                        :transformation_mapping => tm)
    end
  end

  let(:transformation_plan_catalog_item_options) do
    {
      :name        => 'Test Transformation Plan',
      :description => 'Transformation Plan for testing purpose',
      :config_info => {
        :transformation_mapping_id => transformation_mapping.id,
        :pre_service_id            => embedded_ansible_service_template.id,
        :post_service_id           => embedded_ansible_service_template.id,
        :actions                   => [
          {:vm_id => vm_vmware.id.to_s, :pre_service => true, :post_service => true},
        ],
      }
    }
  end
  let(:transformation_plan) { ServiceTemplateTransformationPlan.create_catalog_item(transformation_plan_catalog_item_options) }

  let(:request)     { FactoryBot.create(:service_template_transformation_plan_request, :source => transformation_plan) }
  let(:task)        { FactoryBot.create(:service_template_transformation_plan_task, :miq_request => request, :source => vm_vmware, :userid => user.id) }
  let(:job_options) { {:target_class => task.class.name, :target_id => task.id} }
  let(:job)         { described_class.create_job(job_options) }

  before do
    allow(MiqServer).to receive(:my_zone).and_return(zone.name)
    allow(ServiceTemplateProvisionRequest).to receive(:destination)
  end

  context '.create_job' do
    it 'leaves job waiting to start' do
      job = described_class.create_job(job_options)
      expect(job.state).to eq('waiting_to_start')
    end
  end

  context '.target_vm' do
    it 'returns nil if no phase is set' do
      expect(job.target_vm).to be_nil
    end

    it 'returns migration_task.source if migration phase is "pre"' do
      task.update_options(:migration_phase => 'pre')
      task.reload
      expect(job.target_vm.id).to eq(vm_vmware.id)
    end

    it 'returns vm_redhat if migration phase is "post"' do
      task.update_options(:migration_phase => 'post', :destination_vm_id => vm_redhat.id)
      task.reload
      expect(job.target_vm.id).to eq(vm_redhat.id)
    end
  end

  context 'state hash methods' do
    before do
      job.state = 'running_in_automate'
      job.context[:retries_running_in_automate] = 1728
    end

    context '.on_entry' do
      it 'initializes the state hash if it did not exist' do
        Timecop.freeze(2019, 2, 6) do
          expect(job.on_entry(nil, nil)).to eq(
            :state      => 'active',
            :status     => 'Ok',
            :started_on => Time.now.utc,
            :percent    => 0.0
          )
        end
      end
    end

    context '.on_retry' do
      it 'uses ad-hoc percentage if no progress is provided' do
        Timecop.freeze(2019, 2, 6) do
          state_hash = {
            :state      => 'active',
            :status     => 'Ok',
            :started_on => Time.now.utc - 1.minute,
            :percent    => 10.0
          }
          state_hash_diff = {
            :percent    => 20.0,
            :updated_on => Time.now.utc
          }
          expect(job.on_retry(state_hash, nil)).to eq(state_hash.merge(state_hash_diff))
        end
      end

      it 'uses percentage from progress hash' do
        Timecop.freeze(2019, 2, 6) do
          state_hash = {
            :state      => 'active',
            :status     => 'Ok',
            :started_on => Time.now.utc - 1.minute,
            :percent    => 10.0
          }
          state_hash_diff = {
            :percent    => 25.0,
            :updated_on => Time.now.utc
          }
          expect(job.on_retry(state_hash, :percent => 25.0)).to eq(state_hash.merge(state_hash_diff))
        end
      end
    end

    context '.on_exit' do
      it 'uses percentage from progress hash' do
        Timecop.freeze(2019, 2, 6) do
          state_hash = {
            :state      => 'active',
            :status     => 'Ok',
            :started_on => Time.now.utc - 1.minute,
            :percent    => 80.0
          }
          state_hash_diff = {
            :state      => 'finished',
            :percent    => 100.0,
            :updated_on => Time.now.utc
          }
          expect(job.on_exit(state_hash, nil)).to eq(state_hash.merge(state_hash_diff))
        end
      end
    end

    context '.on_error' do
      it 'uses percentage from progress hash' do
        Timecop.freeze(2019, 2, 6) do
          state_hash = {
            :state      => 'active',
            :status     => 'Ok',
            :started_on => Time.now.utc - 1.minute,
            :percent    => 80.0
          }
          state_hash_diff = {
            :state      => 'finished',
            :status     => 'Error',
            :updated_on => Time.now.utc
          }
          expect(job.on_error(state_hash, nil)).to eq(state_hash.merge(state_hash_diff))
        end
      end
    end

    context '.update_migration_task_progress' do
      it 'initializes the progress hash on entry if it does not exist' do
        Timecop.freeze(2019, 2, 6) do
          job.update_migration_task_progress(:on_entry)
          expect(task.reload.options[:progress]).to eq(
            :current_state => 'running_in_automate',
            :percent       => 0.0,
            :states        => {
              :running_in_automate => {
                :state      => 'active',
                :status     => 'Ok',
                :started_on => Time.now.utc,
                :percent    => 0.0
              }
            }
          )
        end
      end

      it 'updates the task progress hash on retry without a state progress hash' do
        job.context[:retries_running_in_automate] = 1728
        Timecop.freeze(2019, 2, 6) do
          progress = {
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'active',
                :status     => 'Ok',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 10.0,
                :updated_on => Time.now.utc - 30.seconds
              }
            }
          }
          task.update_options(:progress => progress)
          job.update_migration_task_progress(:on_retry)
          expect(task.reload.options[:progress]).to eq(
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'active',
                :status     => 'Ok',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 20.0,
                :updated_on => Time.now.utc
              }
            }
          )
        end
      end

      it 'updates the task progress hash on retry with a state progress hash' do
        job.context[:retries_running_in_automate] = 1728
        Timecop.freeze(2019, 2, 6) do
          progress = {
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'active',
                :status     => 'Ok',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 10.0,
                :updated_on => Time.now.utc - 30.seconds
              }
            }
          }
          task.update_options(:progress => progress)
          job.update_migration_task_progress(:on_retry, :percent => 30)
          expect(task.reload.options[:progress]).to eq(
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'active',
                :status     => 'Ok',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 30.0,
                :updated_on => Time.now.utc
              }
            }
          )
        end
      end

      it 'updates the task progress hash on exit' do
        job.context[:retries_running_in_automate] = 1728
        Timecop.freeze(2019, 2, 6) do
          progress = {
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'active',
                :status     => 'Ok',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 10.0,
                :updated_on => Time.now.utc - 30.seconds
              }
            }
          }
          task.update_options(:progress => progress)
          job.update_migration_task_progress(:on_exit)
          expect(task.reload.options[:progress]).to eq(
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'finished',
                :status     => 'Ok',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 100.0,
                :updated_on => Time.now.utc
              }
            }
          )
        end
      end

      it 'updates the task progress hash on error' do
        job.context[:retries_running_in_automate] = 1728
        Timecop.freeze(2019, 2, 6) do
          progress = {
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'active',
                :status     => 'Ok',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 10.0,
                :updated_on => Time.now.utc - 30.seconds
              }
            }
          }
          task.update_options(:progress => progress)
          job.update_migration_task_progress(:on_error)
          expect(task.reload.options[:progress]).to eq(
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'finished',
                :status     => 'Error',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 10.0,
                :updated_on => Time.now.utc
              }
            }
          )
        end
      end
    end
  end

  context 'state transitions' do
    %w[start remove_snapshots poll_remove_snapshots_complete wait_for_ip_address run_migration_playbook poll_run_migration_playbook_complete poll_automate_state_machine finish abort_job cancel error].each do |signal|
      shared_examples_for "allows #{signal} signal" do
        it signal.to_s do
          expect(job).to receive(signal.to_sym)
          job.signal(signal.to_sym)
        end
      end
    end

    %w[start remove_snapshots poll_remove_snapshots_complete wait_for_ip_address run_migration_playbook poll_run_migration_playbook_complete poll_automate_state_machine].each do |signal|
      shared_examples_for "doesn't allow #{signal} signal" do
        it signal.to_s do
          expect { job.signal(signal.to_sym) }.to raise_error(RuntimeError, /#{signal} is not permitted at state #{job.state}/)
        end
      end
    end

    context 'waiting_to_start' do
      before do
        job.state = 'waiting_to_start'
      end

      it_behaves_like 'allows start signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow remove_snapshots signal'
      it_behaves_like 'doesn\'t allow poll_remove_snapshots_complete signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'started' do
      before do
        job.state = 'started'
      end

      it_behaves_like 'allows remove_snapshots signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow poll_remove_snapshots_complete signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'removing_snapshots' do
      before do
        job.state = 'removing_snapshots'
      end

      it_behaves_like 'allows poll_remove_snapshots_complete signal'
      it_behaves_like 'allows wait_for_ip_address signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow remove_snapshots signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'waiting_for_ip_address' do
      before do
        job.state = 'waiting_for_ip_address'
      end

      it_behaves_like 'allows wait_for_ip_address signal'
      it_behaves_like 'allows run_migration_playbook signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow remove_snapshots signal'
      it_behaves_like 'doesn\'t allow poll_remove_snapshots_complete signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'running_migration_playbook' do
      before do
        job.state = 'running_migration_playbook'
      end

      it_behaves_like 'allows poll_run_migration_playbook_complete signal'
      it_behaves_like 'allows poll_automate_state_machine signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow remove_snapshots signal'
      it_behaves_like 'doesn\'t allow poll_remove_snapshots_complete signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
    end

    context 'running_in_automate' do
      before do
        job.state = 'running_in_automate'
      end

      it_behaves_like 'allows poll_automate_state_machine signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow remove_snapshots signal'
      it_behaves_like 'doesn\'t allow poll_remove_snapshots_complete signal'
      it_behaves_like 'doesn\'t allow wait_for_ip_address signal'
      it_behaves_like 'doesn\'t allow run_migration_playbook signal'
      it_behaves_like 'doesn\'t allow poll_run_migration_playbook_complete signal'
    end
  end

  context 'transition methods' do
    context '#start' do
      it 'to poll_automate_state_machine when preflight_check passes' do
        expect(job).to receive(:queue_signal).with(:remove_snapshots)
        job.signal(:start)
        expect(task.reload.state).to eq('migrate')
      end
    end

    context '#remove_snapshots' do
      before { job.state = 'started' }

      context 'without any snapshots' do
        it 'does not queue the task' do
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(vm_vmware).not_to receive(:remove_all_snapshots)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
          expect(job).to receive(:queue_signal).with(:wait_for_ip_address)
          job.signal(:remove_snapshots)
        end
      end

      context 'with snapshots' do
        before { FactoryBot.create(:snapshot, :vm_or_template => vm_vmware) }

        it 'queues the remove_all_snapshots task' do
          Timecop.freeze(2019, 2, 6) do
            expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
            expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
            expect(job).to receive(:queue_signal).with(:poll_remove_snapshots_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
            job.signal(:remove_snapshots)
            task = MiqTask.find(job.context[:async_task_id_removing_snapshots])
            expect(task).to have_attributes(
              :name   => "Removing all snapshots for #{vm_vmware.name}",
              :state  => MiqTask::STATE_QUEUED,
              :status => MiqTask::STATUS_OK,
              :userid => user.id.to_s
            )
          end
        end
      end
    end

    context '#poll_remove_snapshots_complete' do
      let(:async_task) { FactoryBot.create(:miq_task, :userid => user.id) }

      before do
        job.state = 'removing_snapshots'
        job.context[:async_task_id_removing_snapshots] = async_task.id
      end

      it 'abort_conversion when remove_snapshots times out' do
        job.context[:retries_removing_snapshots] = 960
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_error)
        expect(job).to receive(:abort_conversion).with('Collapsing snapshots timed out', 'error')
        job.signal(:poll_remove_snapshots_complete)
      end

      it 'retries if async task is not finished' do
        async_task.update!(:state => MiqTask::STATE_ACTIVE)
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_retry)
          expect(job).to receive(:queue_signal).with(:poll_remove_snapshots_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
          job.signal(:poll_remove_snapshots_complete)
        end
      end

      it 'exits if async task is finished and its status is Ok' do
        async_task.update!(:state => MiqTask::STATE_FINISHED, :status => MiqTask::STATUS_OK)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job).to receive(:queue_signal).with(:wait_for_ip_address)
        job.signal(:poll_remove_snapshots_complete)
      end

      it 'fails if async task is finished and its status is Error' do
        async_task.update!(:state => MiqTask::STATE_FINISHED, :status => MiqTask::STATUS_ERROR, :message => 'Fake error message')
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_error)
        expect(job).to receive(:abort_conversion).with('Fake error message', 'error')
        job.signal(:poll_remove_snapshots_complete)
      end
    end

    context '#wait_for_ip_address' do
      before do
        task.update_options(:migration_phase => 'pre')
        job.state = 'waiting_for_ip_address'
      end

      it 'abort_conversion when waiting_on_ip_address times out' do
        job.context[:retries_waiting_for_ip_address] = 240
        expect(job).to receive(:abort_conversion).with('Waiting for IP address timed out', 'error')
        job.signal(:wait_for_ip_address)
      end

      it 'exits if VM is powered off' do
        vm_vmware.update!(:raw_power_state => 'poweredOff')
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job).to receive(:queue_signal).with(:run_migration_playbook)
        job.signal(:wait_for_ip_address)
      end

      it 'exits if VM is powered on has an IP address' do
        vm_vmware.update!(:raw_power_state => 'poweredOn')
        network_vmware.update!(:ipaddress => '10.0.0.1')
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job).to receive(:queue_signal).with(:run_migration_playbook)
        job.signal(:wait_for_ip_address)
      end

      it 'retries if VM is powered on and does not have an IP address' do
        vm_vmware.update!(:raw_power_state => 'poweredOn')
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_retry)
        expect(job).to receive(:queue_signal).with(:wait_for_ip_address)
        job.signal(:wait_for_ip_address)
      end
    end

    context '#run_migration_playbook' do
      before do
        task.update_options(:migration_phase => 'pre')
        job.state = 'waiting_for_ip_address'
      end

      context 'without a service template matching the embedded ansible service template id' do
        it 'does not request service template provisioning' do
          embedded_ansible_service_template.delete
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
          expect(job).to receive(:queue_signal).with(:poll_automate_state_machine)
          job.signal(:run_migration_playbook)
          expect(task.reload.options[:workflow_runner]).to eq('automate')
        end
      end

      context 'with a service template matching the embedded ansible service template id' do
        it 'creates a service template provision request' do
          Timecop.freeze(2019, 2, 6) do
            expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
            expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
            expect(job).to receive(:queue_signal).with(:poll_run_migration_playbook_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
            job.signal(:run_migration_playbook)
            service_request = ServiceTemplateProvisionRequest.find(job.context[:pre_migration_playbook_service_request_id])
            expect(service_request).to have_attributes(
              :description => "Provisioning Service [#{embedded_ansible_service_template.name}] from [#{embedded_ansible_service_template.name}]",
              :state       => 'pending',
              :status      => 'Ok',
              :userid      => user.userid
            )
          end
        end
      end
    end

    context '#poll_run_migration_playbook_complete' do
      before do
        task.update_options(:migration_phase => 'pre')
        job.state = 'running_migration_playbook'
        job.context[:pre_migration_playbook_service_request_id] = embedded_ansible_service_request.id
        embedded_ansible_job = FactoryBot.create(:embedded_ansible_job)
        embedded_ansible_service = FactoryBot.create(:service_ansible_playbook)
        embedded_ansible_service_request_task = FactoryBot.create(:service_template_provision_task, :miq_request => embedded_ansible_service_request, :destination => embedded_ansible_service, :userid => user.id)
        embedded_ansible_service_resource = FactoryBot.create(:service_resource, :resource => embedded_ansible_job, :service => embedded_ansible_service)
      end

      it 'abort_conversion when running_migration_playbook times out' do
        job.context[:retries_running_migration_playbook] = 1440
        expect(job).to receive(:abort_conversion).with('Running migration playbook timed out', 'error')
        job.signal(:poll_run_migration_playbook_complete)
      end

      it 'retries if service request is not finished' do
        embedded_ansible_service_request.update!(:request_state => 'active')
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
          expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_retry)
          expect(job).to receive(:queue_signal).with(:poll_run_migration_playbook_complete, :deliver_on => Time.now.utc + job.state_retry_interval)
          job.signal(:poll_run_migration_playbook_complete)
        end
      end

      it 'exits if service request is finished and its status is Ok' do
        embedded_ansible_service_request.update!(:request_state => 'finished', :status => 'Ok')
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job).to receive(:queue_signal).with(:poll_automate_state_machine)
        job.signal(:poll_run_migration_playbook_complete)
        expect(task.reload.options[:workflow_runner]).to eq('automate')
      end

      it 'fails if service request is finished and migration_phase is "pre" and its status is Error' do
        embedded_ansible_service_request.update!(:state => 'finished', :status => 'Error')
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_error)
        expect(job).to receive(:abort_conversion).with('Ansible playbook has failed (migration_phase=pre)', 'error')
        job.signal(:poll_run_migration_playbook_complete)
      end

      it 'exits if service request is finished and migration_phase is "post" and its status is Error' do
        task.update_options(:migration_phase => 'post')
        job.context[:post_migration_playbook_service_request_id] = embedded_ansible_service_request.id
        embedded_ansible_service_request.update!(:state => 'finished', :status => 'Error', :message => 'Fake error message')
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_entry)
        expect(job).to receive(:update_migration_task_progress).once.ordered.with(:on_exit)
        expect(job).to receive(:queue_signal).with(:poll_automate_state_machine)
        job.signal(:poll_run_migration_playbook_complete)
        expect(task.reload.options[:workflow_runner]).to eq('automate')
      end
    end

    context '#poll_automate_state_machine' do
      before do
        job.state = 'running_in_automate'
      end

      it 'abort_conversion when running_in_automate times out' do
        job.context[:retries_running_in_automate] = 8640
        expect(job).to receive(:abort_conversion).with('Polling Automate state machine timed out', 'error')
        job.signal(:poll_automate_state_machine)
      end

      it 'to poll_automate_state_machine when migration_task.state is not finished' do
        task.update!(:state => 'migrate')
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:queue_signal).with(:poll_automate_state_machine, :deliver_on => Time.now.utc + job.state_retry_interval)
          job.signal(:poll_automate_state_machine)
        end
      end

      it 'to finish when migration_task.state is finished' do
        task.update!(:state => 'finished', :status => 'Ok')
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:queue_signal).with(:finish)
          job.signal(:poll_automate_state_machine)
          expect(job.status).to eq(task.status)
        end
      end
    end
  end
end
