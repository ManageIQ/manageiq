describe(ServiceAnsiblePlaybook) do
  let(:tower_job)      { FactoryGirl.create(:ansible_tower_job) }
  let(:tower_job_temp) { FactoryGirl.create(:ansible_configuration_script) }
  let(:basic_service)  { FactoryGirl.create(:service_ansible_playbook, :options => dialog_options) }
  let(:action)         { ResourceAction::PROVISION }

  let(:loaded_service) do
    service_template = FactoryGirl.create(:service_template_ansible_playbook)
    service_template.resource_actions.build(:action => action, :configuration_template => tower_job_temp)
    service_template.save!
    FactoryGirl.create(:service_ansible_playbook, :options => provision_options, :service_template => service_template)
  end

  let(:executed_service) do
    basic_service.tap do |service|
      allow(service).to receive(:job).with(action).and_return(tower_job)
    end
  end

  let(:dialog_options) do
    {
      :dialog => {
        'dialog_hosts'         => 'host1,host2',
        'dialog_credential_id' => 1,
        'dialog_param_var1'    => 'value1',
        'dialog_param_var2'    => 'value2'
      }
    }
  end

  let(:override_options) do
    {
      :hosts      => 'host3',
      :extra_vars => { 'var1' => 'new_val1' }
    }
  end

  let(:provision_options) { {:provision_job_options => override_options} }

  describe '#preprocess' do
    it 'prepares options for action' do
      basic_service.preprocess(action, override_options)
      basic_service.reload
      expect(basic_service.options[:provision_job_options]).to have_attributes(
        :hosts         => 'host3',
        :credential_id => 1,
        :extra_vars    => {'var1' => 'new_val1', 'var2' => 'value2'}
      )
    end
  end

  describe '#execute' do
    it 'creates an Ansible Tower job' do
      expect(ManageIQ::Providers::AnsibleTower::AutomationManager::Job)
        .to receive(:create_job).with(tower_job_temp, provision_options[:provision_job_options]).and_return(tower_job)
      loaded_service.execute(action)
      expect(loaded_service.job(action)).to eq(tower_job)
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
end
