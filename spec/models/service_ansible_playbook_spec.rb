describe(ServiceAnsiblePlaybook) do
  let(:tower_job)      { FactoryGirl.create(:ansible_tower_job) }
  let(:tower_job_temp) { FactoryGirl.create(:ansible_configuration_script) }
  let(:task_options) { { } }
  let(:miq_request_task) { FactoryGirl.create(:miq_request_task, :options => task_options) }
  let(:basic_service) do
    FactoryGirl.create(:service_ansible_playbook,
                       :options => config_info_options).tap do |svc|
      svc.miq_request_task = miq_request_task
    end
  end
  let(:service) do
    FactoryGirl.create(:service_ansible_playbook,
                       :options => config_info_options.merge(dialog_options)).tap do |svc|
      svc.miq_request_task = miq_request_task
    end
  end
  let(:action)         { ResourceAction::PROVISION }
  let(:credential_1)   { FactoryGirl.create(:authentication, :manager_ref => 'a') }
  let(:credential_2)   { FactoryGirl.create(:authentication, :manager_ref => 'b') }
  let(:value1)         { 'value1' }
  let(:value2)         { 'value2' }
  let(:resolved_value1) { 'value1' }
  let(:resolved_value2) { 'value2' }

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
      allow(service).to receive(:job).with(action).and_return(tower_job)
    end
  end

  let(:dialog_options) do
    {
      :dialog => {
        'dialog_hosts'      => 'host1,host2',
        'dialog_credential' => credential_1.id,
        'dialog_param_var1' => value1,
        'dialog_param_var2' => value2
      }
    }
  end

  let(:config_info_options) do
    {
      :config_info => {
        :provision => {
          :hosts       => "default_host1,default_host2",
          :playbook_id => 10,
          :extra_vars  => {
            "var1" => "default_val1",
            "var2" => "default_val2",
            "var3" => "default_val3"
          },
        }
      }
    }
  end

  let(:override_options) do
    {
      :credential_id => credential_2.id,
      :hosts         => 'host3',
      :extra_vars    => { 'var1' => 'new_val1' }
    }
  end

  let(:provision_options) do
    {
      :provision_job_options => {
        :credential => 1,
        :inventory  => 2,
        :hosts      => "default_host1,default_host2",
        :extra_vars => {'var1' => value1, 'var2' => value2}
      }
    }
  end

  let(:vm) { FactoryGirl.create(:vm_vmware, :name => "test_vm") }
  let(:event) { FactoryGirl.create(:miq_event, :message => "hello%20moto") }

  shared_examples_for "basic_service with substitution" do
    it 'prepares job options combines from service template and dialog after erb subst' do
      hosts = dialog_options[:dialog]['dialog_hosts']
      expect(service).to receive(:create_inventory_with_hosts).with(action, hosts).and_return(double(:id => 20))
      service.preprocess(action)
      service.reload
      expect(service.options[:provision_job_options]).to have_attributes(
        :inventory  => 20,
        :credential => credential_1.manager_ref,
        :extra_vars => {'var1' => resolved_value1, 'var2' => resolved_value2, 'var3' => 'default_val3'}
      )
    end
  end

  describe '#preprocess' do
    context 'basic service' do
      it 'prepares job options from service template' do
        hosts = config_info_options.fetch_path(:config_info, :provision, :hosts)
        expect(basic_service).to receive(:create_inventory_with_hosts).with(action, hosts).and_return(double(:id => 10))
        basic_service.preprocess(action)
        service.reload
        expect(basic_service.options[:provision_job_options]).to have_attributes(:inventory => 10)
      end
    end

    context 'with dialog overrides' do
      it 'prepares job options combines from service template and dialog' do
        hosts = dialog_options[:dialog]['dialog_hosts']
        expect(service).to receive(:create_inventory_with_hosts).with(action, hosts).and_return(double(:id => 20))
        service.preprocess(action)
        service.reload
        expect(service.options[:provision_job_options]).to have_attributes(
          :inventory  => 20,
          :credential => credential_1.manager_ref,
          :extra_vars => {'var1' => resolved_value1, 'var2' => resolved_value2, 'var3' => 'default_val3'}
        )
      end
    end

    context 'with runtime overrides' do
      it 'prepares job options combined from service template, dialog, and overrides' do
        hosts = override_options[:hosts]
        expect(service).to receive(:create_inventory_with_hosts).with(action, hosts).and_return(double(:id => 30))
        service.preprocess(action, override_options)
        service.reload
        expect(service.options[:provision_job_options]).to have_attributes(
          :inventory  => 30,
          :credential => credential_2.manager_ref,
          :extra_vars => {'var1' => 'new_val1', 'var2' => 'value2', 'var3' => 'default_val3'}
        )
      end
    end
  end

  describe '#execute' do
    it 'creates an Ansible Tower job' do
      expect(ManageIQ::Providers::AnsibleTower::AutomationManager::Job)
        .to receive(:create_job).with(tower_job_temp, provision_options[:provision_job_options]).and_return(tower_job)
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
    it 'deletes inventory' do
      expect(executed_service).to receive(:delete_inventory)
      executed_service.postprocess(action)
    end
  end

  shared_context "shared variables" do
    let(:value1)    { '<%= vm.name %>' }
    let(:value2)    { '<%= event.message %>' }
    let(:resolved_value1) { vm.name }
    let(:resolved_value2) { event.message }
    let(:obj1) { {:name => 'vm', :class => vm.class.to_s, :id => vm.id} }
    let(:obj2) { {:name => 'event', :class => event.class.to_s, :id => event.id} }
  end

  describe 'substitution' do
    context 'success' do
      include_context "shared variables"
      let(:task_options) { { :expose_objects => [obj1, obj2] } }

      it_behaves_like "basic_service with substitution"
    end

    context 'failure' do
      include_context "shared variables"
      let(:task_options) { { :expose_objects => [obj1] } }

      it "raises NameError if any of the objects is missing" do
        expect { service.preprocess(action) }.to raise_error(NameError)
      end
    end
  end
end
