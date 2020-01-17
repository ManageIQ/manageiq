RSpec.describe(ServiceContainerTemplate) do
  let(:action) { ResourceAction::PROVISION }
  let(:stack_status) { double("ManageIQ::Providers::Openshift::ContainerManager::OrchestrationStack::Status") }
  let(:stack) do
    double("ManageIQ::Providers::Openshift::ContainerManager::OrchestrationStack", :resources => [created_object], :raw_status => stack_status)
  end

  let(:ems) do
    FactoryBot.create(:ems_openshift).tap do |ems|
      allow(ems).to receive(:create_project)
    end
  end

  let(:service) do
    FactoryBot.create(:service_container_template, :options => config_info_options.merge(dialog_options)).tap do |svc|
      allow(svc).to receive(:container_manager).and_return(ems)
    end
  end

  let(:service_with_new_project) do
    FactoryBot.create(:service_container_template, :options => config_info_options.merge(dialog_options_with_new_project)).tap do |svc|
      allow(svc).to receive(:container_manager).and_return(ems)
    end
  end

  let(:loaded_service) do
    service_template = FactoryBot.create(:service_template_container_template).tap do |st|
      allow(st).to receive(:container_manager).and_return(ems)
    end

    FactoryBot.create(:service_container_template,
                       :options          => provision_options.merge(config_info_options),
                       :service_template => service_template).tap do |svc|
      allow(svc).to receive(:container_template).and_return(container_template)
      allow(svc).to receive(:stack).and_return(stack)
    end
  end

  let(:dialog_options) do
    {
      :dialog => {
        'dialog_existing_project_name' => 'old_project',
        'dialog_param_var1'            => 'value1',
        'dialog_param_var2'            => 'value2'
      }
    }
  end

  let(:dialog_options_with_new_project) do
    {
      :dialog => {
        'dialog_existing_project_name' => 'old_project',
        'dialog_new_project_name'      => 'new_project',
        'dialog_param_var1'            => 'value1',
        'dialog_param_var2'            => 'value2'
      }
    }
  end

  let(:config_info_options) do
    {
      :config_info => {
        :provision => {
          :dialog_id          => 2,
          :container_template => container_template
        }
      }
    }
  end

  let(:override_options) { {:new_project_name => 'override_project', :var1 => 'new_val1'} }

  let(:provision_options) do
    {
      :provision_options => {
        :container_project_name => 'my-project',
        :parameters             => {'var1' => 'value1', 'var2' => 'value2'}
      }
    }
  end

  let(:ctp1) { FactoryBot.create(:container_template_parameter, :name => 'var1', :value => 'p1', :required => true) }
  let(:ctp2) { FactoryBot.create(:container_template_parameter, :name => 'var2', :value => 'p2', :required => true) }
  let(:ctp3) { FactoryBot.create(:container_template_parameter, :name => 'var3', :value => 'p3', :required => false) }
  let(:container_template) do
    FactoryBot.create(:container_template, :ems_id => ems.id).tap do |ct|
      ct.container_template_parameters = [ctp1, ctp2, ctp3]
    end
  end

  let(:created_object) { FactoryBot.create(:orchestration_stack_resource, :name => 'my-example', :resource_category => 'ContainerRoute') }
  let(:object_hash) { {:apiVersion => "v1", :kind => "Route", :metadata => {:name => "dotnet-example"}} }

  describe '#preprocess' do
    it 'prepares job options from dialog' do
      expect(ems).not_to receive(:create_project)
      service.preprocess(action)
      expect(service.options[:provision_options]).to include(
        :container_project_name => 'old_project',
        :parameters             => {"var1" => "value1", "var2" => "value2"}
      )
    end

    it 'honors new project name more than existing project name' do
      expect(ems).to receive(:create_project)
      service_with_new_project.preprocess(action)
      expect(service_with_new_project.options[:provision_options]).to include(
        :container_project_name => 'new_project',
        :parameters             => {"var1" => "value1", "var2" => "value2"}
      )
    end

    it 'prepares job options combined from dialog and overrides' do
      expect(ems).to receive(:create_project)
      service_with_new_project.preprocess(action, override_options)
      expect(service_with_new_project.options[:provision_options]).to include(
        :container_project_name => 'override_project',
        :parameters             => {'var1' => 'new_val1', 'var2' => 'value2'}
      )
    end
  end

  describe '#execute' do
    it 'Provisions with a container template' do
      expect(container_template).to receive(:instantiate) do |params, project_name|
        expect(project_name).to eq(provision_options.fetch_path(:provision_options, :container_project_name))
        expect(params).to match_array([ctp1, ctp2, ctp3])
        expect(ctp1.value).to eq(provision_options.fetch_path(:provision_options, :parameters, ctp1.name))
        expect(ctp2.value).to eq(provision_options.fetch_path(:provision_options, :parameters, ctp2.name))
        expect(ctp3.value).to eq(ctp3.value)
        [object_hash]
      end
      loaded_service.execute(action)
    end
  end

  describe '#check_completed' do
    it 'created container object ends in VMDB' do
      allow(stack_status).to receive(:normalized_status).and_return(%w(create_complete completed))
      expect(loaded_service.check_completed(action)).to eq([true, nil])
    end

    it 'created container object not ends in VMDB yet' do
      allow(stack_status).to receive(:normalized_status).and_return(['transient', 'in progress'])
      expect(loaded_service.check_completed(action)).to eq([false, 'in progress'])
    end
  end

  describe '#check_refreshed' do
    it { expect(loaded_service.check_refreshed(action)).to eq([true, nil]) }
  end
end
