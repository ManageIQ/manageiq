RSpec.describe(ServiceAnsiblePlaybook) do
  let(:runner_job)      { FactoryBot.create(:embedded_ansible_job) }
  let(:playbook)        { FactoryBot.create(:embedded_playbook) }
  let(:basic_service)   { FactoryBot.create(:service_ansible_playbook, :options => config_info_options) }
  let(:service)         { FactoryBot.create(:service_ansible_playbook, :options => config_info_options.merge(dialog_options)) }
  let(:action)          { ResourceAction::PROVISION }
  let(:credential_0)    { FactoryBot.create(:embedded_ansible_credential, :manager_ref => '1') }
  let(:credential_1)    { FactoryBot.create(:embedded_ansible_credential, :manager_ref => '2') }
  let(:credential_2)    { FactoryBot.create(:embedded_ansible_credential, :manager_ref => '3') }
  let(:credential_3)    { FactoryBot.create(:embedded_ansible_credential, :manager_ref => '4') }
  let(:decrpyted_val)   { 'my secret' }
  let(:encrypted_val)   { ManageIQ::Password.encrypt(decrpyted_val) }
  let(:encrypted_val2)  { ManageIQ::Password.encrypt(decrpyted_val + "new") }

  let(:loaded_service) do
    service_template = FactoryBot.create(:service_template_ansible_playbook, :options => config_info_options)
    FactoryBot.create(:service_ansible_playbook,
                      :options          => provision_options.merge(config_info_options),
                      :service_template => service_template)
  end

  let(:executed_service) do
    FactoryBot.create(:service_ansible_playbook, :options => provision_options).tap do |service|
      regex = /(#{ResourceAction::PROVISION})|(#{ResourceAction::RETIREMENT})/
      allow(service).to receive(:job).with(regex).and_return(runner_job)
    end
  end

  let(:dialog_options) do
    {
      :dialog => {
        'dialog_hosts'                => 'host1,host2',
        'dialog_credential'           => credential_1.id,
        'dialog_param_var1'           => 'value1',
        'dialog_param_var2'           => 'value2',
        'password::dialog_param_pswd' => encrypted_val
      }
    }
  end

  let(:config_info_options) do
    {
      :config_info => {
        :provision => {
          :hosts               => "default_host1,default_host2",
          :credential_id       => credential_0.id,
          :vault_credential_id => credential_3.id,
          :playbook_id         => playbook.id,
          :execution_ttl       => "5",
          :verbosity           => "3",
          :become_enabled      => true,
          :extra_vars          => {
            "var1" => {:default => "default_val1"},
            :var2  => {:default => "default_val2"},
            "var3" => {:default => "default_val3"}
          },
        }
      }
    }
  end

  let(:override_options) do
    {
      :credential_id => credential_2.id,
      :hosts         => 'host3',
      'extra_vars'   => { :var1 => 'new_val1', 'pswd' => encrypted_val2 }
    }
  end

  let(:provision_options) do
    {
      :provision_job_options => {
        :credential => 1,
        :vault_credential => 2,
        :inventory  => 2,
        :hosts      => "default_host1,default_host2",
        :extra_vars => {'var1' => 'value1', 'var2' => 'value2', 'pswd' => encrypted_val}
      }
    }
  end

  shared_examples_for "#retain_resources_on_retirement" do
    it "has config_info retirement options" do
      service_options = service.options
      service_options[:config_info][:retirement] = service_options[:config_info][:provision]
      service_options[:config_info][:retirement][:remove_resources] = remove_resources
      service.update(:options => service_options)
      expect(service.retain_resources_on_retirement?).to eq(!can_children_be_retired?)
    end
  end

  describe '#retain_resources_on_retirement?' do
    context "no_with_playbook returns true" do
      let(:remove_resources) { 'no_with_playbook' }
      let(:can_children_be_retired?) { false }
      it_behaves_like "#retain_resources_on_retirement"
    end

    context "no_without_playbook returns true" do
      let(:remove_resources) { 'no_without_playbook' }
      let(:can_children_be_retired?) { false }
      it_behaves_like "#retain_resources_on_retirement"
    end

    context "yes_with_playbook returns false" do
      let(:remove_resources) { 'yes_with_playbook' }
      let(:can_children_be_retired?) { true }
      it_behaves_like "#retain_resources_on_retirement"
    end

    context "yes_without_playbook returns false" do
      let(:remove_resources) { 'yes_without_playbook' }
      let(:can_children_be_retired?) { true }
      it_behaves_like "#retain_resources_on_retirement"
    end
  end

  describe '#preprocess' do
    context 'basic service' do
      it 'prepares job options from service template' do
        basic_service.preprocess(action)
        service.reload
        expect(basic_service.options[:provision_job_options]).to include(
          :hosts            => "default_host1,default_host2",
          :credential       => credential_0.native_ref,
          :vault_credential => credential_3.native_ref,
          :execution_ttl    => "5",
          :verbosity        => "3",
          :become_enabled   => true
        )
      end
    end

    context 'with dialog overrides' do
      it 'prepares job options combines from service template and dialog' do
        service.preprocess(action)
        service.reload
        expect(service.options[:provision_job_options]).to include(
          :hosts            => "host1,host2",
          :credential       => credential_1.native_ref,
          :vault_credential => credential_3.native_ref,
          :execution_ttl    => "5",
          :verbosity        => "3",
          :become_enabled   => true,
          :extra_vars       => {
            'var1' => 'value1',
            'var2' => 'value2',
            'var3' => 'default_val3',
            'pswd' => encrypted_val
          }
        )
      end

      context 'action is retirement' do
        let(:action) { ResourceAction::RETIREMENT }

        before do
          service_options = service.options
          service_options[:config_info][:retirement] = service_options[:config_info][:provision]
          service.update(:options => service_options)
        end

        it 'ignores dialog options' do
          service.preprocess(action)
          service.reload
          expect(service.options[:retirement_job_options]).to include(
            :hosts            => "default_host1,default_host2",
            :credential       => credential_0.native_ref,
            :vault_credential => credential_3.native_ref,
            :execution_ttl    => "5",
            :verbosity        => "3",
            :become_enabled   => true,
            :extra_vars       => {
              'var1' => 'default_val1',
              'var2' => 'default_val2',
              'var3' => 'default_val3'
            }
          )
        end
      end
    end

    context 'with runtime overrides' do
      it 'prepares job options combined from service template, dialog, and overrides' do
        service.preprocess(action, override_options)
        service.reload
        expect(service.options[:provision_job_options][:hosts]).to eq("host3")
        expect(service.options[:provision_job_options][:credential]).to eq(credential_2.native_ref)
        expect(service.options[:provision_job_options][:extra_vars]).to eq(
          'var1' => 'new_val1', 'var2' => 'value2', 'var3' => 'default_val3', 'pswd' => encrypted_val2
        )
      end
    end
  end

  describe '#launch_ansible_job' do
    let(:control_extras) { {'a' => 'A', 'b' => 'B', 'c' => 'C'} }
    before do
      FactoryBot.create(:miq_region, :region => ApplicationRecord.my_region_number)
      miq_request_task = FactoryBot.create(:miq_request_task, :miq_request => FactoryBot.create(:service_template_provision_request))
      miq_request_task.update(:options => {:request_options => {:manageiq_extra_vars => control_extras}})
      loaded_service.update(:evm_owner        => FactoryBot.create(:user_with_group),
                                       :miq_group        => FactoryBot.create(:miq_group),
                                       :miq_request_task => miq_request_task)
    end

    it 'creates an Ansible Runner job' do
      expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job).to receive(:create_job) do |jobtemp, opts|
        expect(jobtemp).to eq(playbook)
        exposed_miq = %w(api_url api_token service user group X_MIQ_Group request_task request) + control_extras.keys
        exposed_connection = %w(url token X_MIQ_Group)
        expect(opts[:extra_vars].delete('manageiq').keys).to include(*exposed_miq)
        expect(opts[:extra_vars].delete('manageiq_connection').keys).to include(*exposed_connection)

        expected_opts = provision_options[:provision_job_options].except(:hosts)
        expected_opts[:extra_vars]['pswd'] = decrpyted_val
        expect(opts).to include(expected_opts)
        runner_job
      end
      loaded_service.launch_ansible_job(action)
      expected_job_attributes = {
        :id                           => runner_job.id,
        :hosts                        => config_info_options.fetch_path(:config_info, :provision, :hosts).split(','),
        :configuration_script_base_id => config_info_options.fetch_path(:config_info, :provision, :playbook_id)
      }
      expect(loaded_service.job(action)).to have_attributes(expected_job_attributes)
    end

    it 'uses automate timeout if no execution_ttl' do
      expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job).to receive(:create_job) do |_jobtemp, opts|
        expect(opts[:execution_ttl]).to eq(77)
        runner_job
      end
      expect(loaded_service.options[:provision_job_options][:execution_ttl]).to be nil
      loaded_service.options[:provision_automate_timeout] = 77
      loaded_service.launch_ansible_job(action)
    end

    it 'uses specified execution_ttl' do
      timeout = config_info_options.dig(:config_info, :provision, :execution_ttl)
      expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job).to receive(:create_job) do |_jobtemp, opts|
        expect(opts[:execution_ttl]).to eq(timeout)
        runner_job
      end
      loaded_service.options[:provision_job_options][:execution_ttl] = timeout
      loaded_service.options[:provision_automate_timeout] = 77
      loaded_service.launch_ansible_job(action)
    end
  end

  describe '#launch_ansible_job_queue' do
    it "delivers to the queue" do
      task = double("miq_task", :status_ok? => true)
      request = double("miq_request", :my_zone => 'test')
      allow(loaded_service).to receive(:miq_request).and_return(request)
      q_options = {
        :args        => [action],
        :class_name  => described_class.name,
        :instance_id => loaded_service.id,
        :method_name => "launch_ansible_job",
        :role        => "embedded_ansible",
        :zone        => request.my_zone
      }

      expect(MiqQueue).to receive(:put).with(hash_including(q_options))
      expect(MiqTask).to receive(:wait_for_taskid).and_return(task)
      loaded_service.launch_ansible_job_queue(action)
    end
  end

  describe '#check_completed' do
    shared_examples 'checking progress for job execution' do |raw_status, expected_return|
      before do
        allow(runner_job).to receive(:raw_status).and_return(double(:normalized_status => raw_status))
      end

      it { expect(executed_service.check_completed(action)).to eq(expected_return) }
    end

    context 'job completed without error' do
      it_behaves_like 'checking progress for job execution', ['create_complete', 'ok'], [true, nil]
    end

    context 'job completed with error' do
      it_behaves_like 'checking progress for job execution', ['create_failed', 'bad'], [true, 'bad']
    end

    context 'job is still running' do
      it_behaves_like 'checking progress for job execution', ['transient', nil], [false, nil]
    end
  end

  describe '#refresh' do
    it 'syncs with the runner for the completed job' do
      expect(runner_job).to receive(:refresh_ems)
      executed_service.refresh(action)
    end
  end

  describe '#check_refreshed' do
    it { expect(executed_service.check_refreshed(action)).to eq([true, nil]) }
  end

  describe '#on_error' do
    it 'handles retirement error' do
      executed_service.update(:retirement_state => 'Retiring')
      expect(runner_job).to receive(:refresh_ems)
      executed_service.on_error(ResourceAction::RETIREMENT)
      expect(executed_service.retirement_state).to eq('error')
    end

    it 'handles provisioning error' do
      expect(runner_job).to receive(:refresh_ems)
      executed_service.on_error(action)
      expect(executed_service.retirement_state).to be_nil
    end
  end

  describe '#job' do
    before { service.add_resource!(runner_job, :name => action) }

    it 'retrieves an executed job' do
      expect(service.job(action)).to eq(runner_job)
    end

    it 'returns nil for non-existing job' do
      expect(service.job('Retirement')).to be_nil
    end
  end

  describe '#hosts_array (private)' do
    it "is localhost if the hosts list is empty" do
      hosts = ""
      expect(basic_service.send(:hosts_array, hosts)).to eq(["localhost"])
    end

    it "is localhost if the hosts list is nil" do
      hosts = nil
      expect(basic_service.send(:hosts_array, hosts)).to eq(["localhost"])
    end

    it "handles multiple hosts" do
      hosts = "192.0.2.0,192.0.2.1,192.0.2.2"
      expect(basic_service.send(:hosts_array, hosts)).to match_array(%w[192.0.2.0 192.0.2.1 192.0.2.2])
    end

    it "works with weird commas" do
      hosts = "192.0.2.0, , 192.0.2.1, 192.0.2.2  ,,,"
      expect(basic_service.send(:hosts_array, hosts)).to match_array(%w[192.0.2.0 192.0.2.1 192.0.2.2])
    end
  end
end
