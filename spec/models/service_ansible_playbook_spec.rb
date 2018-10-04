describe(ServiceAnsiblePlaybook) do
  let(:tower_job)      { FactoryGirl.create(:embedded_ansible_job) }
  let(:tower_job_temp) { FactoryGirl.create(:ansible_configuration_script) }
  let(:basic_service)  { FactoryGirl.create(:service_ansible_playbook, :options => config_info_options) }
  let(:service)        { FactoryGirl.create(:service_ansible_playbook, :options => config_info_options.merge(dialog_options)) }
  let(:action)         { ResourceAction::PROVISION }
  let(:credential_0)   { FactoryGirl.create(:authentication, :manager_ref => '1') }
  let(:credential_1)   { FactoryGirl.create(:authentication, :manager_ref => 'a') }
  let(:credential_2)   { FactoryGirl.create(:authentication, :manager_ref => 'b') }
  let(:credential_3)   { FactoryGirl.create(:authentication, :manager_ref => '2') }
  let(:decrpyted_val)  { 'my secret' }
  let(:encrypted_val)  { MiqPassword.encrypt(decrpyted_val) }
  let(:encrypted_val2) { MiqPassword.encrypt(decrpyted_val + "new") }

  let(:loaded_service) do
    service_template = FactoryGirl.create(:service_template_ansible_playbook)
    service_template.resource_actions.build(:action => action, :configuration_template => tower_job_temp)
    service_template.save!
    FactoryGirl.create(:service_ansible_playbook,
                       :options          => provision_options.merge(config_info_options),
                       :service_template => service_template)
  end

  let(:executed_service) do
    FactoryGirl.create(:service_ansible_playbook, :options => provision_options).tap do |service|
      regex = /(#{ResourceAction::PROVISION})|(#{ResourceAction::RETIREMENT})/
      allow(service).to receive(:job).with(regex).and_return(tower_job)
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
          :playbook_id         => 10,
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

  describe '#preprocess' do
    context 'basic service' do
      it 'prepares job options from service template' do
        hosts = config_info_options.fetch_path(:config_info, :provision, :hosts)
        expect(basic_service).to receive(:create_inventory_with_hosts).with(action, hosts).and_return(double(:id => 10))
        basic_service.preprocess(action)
        service.reload
        expect(basic_service.options[:provision_job_options]).to include(:inventory => 10)
      end
    end

    context 'with dialog overrides' do
      it 'prepares job options combines from service template and dialog' do
        hosts = dialog_options[:dialog]['dialog_hosts']
        expect(service).to receive(:create_inventory_with_hosts).with(action, hosts).and_return(double(:id => 20))
        service.preprocess(action)
        service.reload
        expect(service.options[:provision_job_options]).to include(
          :inventory  => 20,
          :credential => credential_1.manager_ref,
          :extra_vars => {'var1' => 'value1', 'var2' => 'value2', 'var3' => 'default_val3', 'pswd' => encrypted_val}
        )
      end

      context 'action is retirement' do
        let(:action) { ResourceAction::RETIREMENT }

        before do
          service_options = service.options
          service_options[:config_info][:retirement] = service_options[:config_info][:provision]
          service.update_attributes(:options => service_options)
        end

        it 'ignores dialog options' do
          hosts = service.options.fetch_path(:config_info, :retirement, :hosts)
          expect(service).to receive(:create_inventory_with_hosts).with(action, hosts).and_return(double(:id => 20))
          service.preprocess(action)
          service.reload
          expect(service.options[:retirement_job_options]).to include(
            :inventory  => 20,
            :extra_vars => {'var1' => 'default_val1', 'var2' => 'default_val2', 'var3' => 'default_val3'}
          )
          expect(service.options[:retirement_job_options]).not_to have_key(:credential)
        end
      end
    end

    context 'with runtime overrides' do
      it 'prepares job options combined from service template, dialog, and overrides' do
        hosts = override_options[:hosts]
        expect(service).to receive(:create_inventory_with_hosts).with(action, hosts).and_return(double(:id => 30))
        service.preprocess(action, override_options)
        service.reload
        expect(service.options[:provision_job_options]).to include(
          :inventory  => 30,
          :credential => credential_2.manager_ref,
          :extra_vars => {'var1' => 'new_val1', 'var2' => 'value2', 'var3' => 'default_val3', 'pswd' => encrypted_val2}
        )
      end
    end
  end

  describe '#execute' do
    let(:control_extras) { {'a' => 'A', 'b' => 'B', 'c' => 'C'} }
    before do
      FactoryGirl.create(:miq_region, :region => ApplicationRecord.my_region_number)
      miq_request_task = FactoryGirl.create(:miq_request_task, :miq_request => FactoryGirl.create(:service_template_provision_request))
      miq_request_task.update_attributes(:options => {:request_options => {:manageiq_extra_vars => control_extras}})
      loaded_service.update_attributes(:evm_owner        => FactoryGirl.create(:user_with_group),
                                       :miq_group        => FactoryGirl.create(:miq_group),
                                       :miq_request_task => miq_request_task)
    end

    it 'creates an Ansible Tower job' do
      expect(ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job).to receive(:create_job) do |jobtemp, opts|
        expect(jobtemp).to eq(tower_job_temp)
        exposed_miq = %w(api_url api_token service user group X_MIQ_Group request_task request) + control_extras.keys
        exposed_connection = %w(url token X_MIQ_Group)
        expect(opts[:extra_vars].delete('manageiq').keys).to include(*exposed_miq)
        expect(opts[:extra_vars].delete('manageiq_connection').keys).to include(*exposed_connection)

        expected_opts = provision_options[:provision_job_options].except(:hosts)
        expected_opts[:extra_vars]['pswd'] = decrpyted_val
        expect(opts).to include(expected_opts)
        tower_job
      end
      loaded_service.execute(action)
      expected_job_attributes = {
        :id                           => tower_job.id,
        :hosts                        => config_info_options.fetch_path(:config_info, :provision, :hosts).split(','),
        :configuration_script_base_id => config_info_options.fetch_path(:config_info, :provision, :playbook_id)
      }
      expect(loaded_service.job(action)).to have_attributes(expected_job_attributes)
    end
  end

  describe '#check_completed' do
    shared_examples 'checking progress for job execution' do |raw_status, expected_return|
      before do
        allow(tower_job).to receive(:raw_status).and_return(double(:normalized_status => raw_status))
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
    it 'syncs with the tower for the completed job' do
      expect(tower_job).to receive(:refresh_ems)
      executed_service.refresh(action)
    end
  end

  describe '#check_refreshed' do
    it { expect(executed_service.check_refreshed(action)).to eq([true, nil]) }
  end

  describe '#postprocess' do
    context 'with user selected hosts' do
      it 'deletes temporary inventory' do
        expect(executed_service).to receive(:delete_inventory)
        expect(executed_service).to receive(:log_stdout)
        executed_service.postprocess(action)
      end
    end

    context 'with default localhost' do
      let(:provision_options) do
        {
          :provision_job_options => {
            :credential => 1,
            :extra_vars => {'var1' => 'value1', 'var2' => 'value2', 'pswd' => encrypted_val}
          }
        }
      end

      it 'needs not to delete the inventory' do
        expect(executed_service).to receive(:log_stdout)
        expect(executed_service).not_to receive(:delete_inventory)
        executed_service.postprocess(action)
      end
    end

    context 'require log stdout when job failed' do
      before do
        status = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job::Status.new('failed', nil)
        allow(tower_job).to receive(:raw_status).and_return(status)
      end

      it 'writes stdout to log' do
        expect(tower_job).to receive(:raw_stdout).with('txt_download')
        expect(executed_service).to receive(:delete_inventory)
        executed_service.postprocess(action)
      end
    end
  end

  describe '#on_error' do
    it 'handles retirement error' do
      executed_service.update_attributes(:retirement_state => 'Retiring')
      expect(tower_job).to receive(:refresh_ems)
      expect(executed_service).to receive(:postprocess)
      executed_service.on_error(ResourceAction::RETIREMENT)
      expect(executed_service.retirement_state).to eq('error')
    end

    it 'handles provisioning error' do
      expect(tower_job).to receive(:refresh_ems)
      expect(executed_service).to receive(:postprocess)
      executed_service.on_error(action)
      expect(executed_service.retirement_state).to be_nil
    end
  end

  describe '#job' do
    before { service.add_resource!(tower_job, :name => action) }

    it 'retrieves an executed job' do
      expect(service.job(action)).to eq(tower_job)
    end

    it 'returns nil for non-existing job' do
      expect(service.job('Retirement')).to be_nil
    end
  end
end
