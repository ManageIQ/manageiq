require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/Cloud/Orchestration/Operations' \
                        '/Methods.class/__methods__/available_resource_groups.rb').to_s

describe ManageIQ::Automate::Cloud::Orchestration::Operations::AvailableResoureceGroups do
  let(:root_hash) do
    { 'service_template' => MiqAeMethodService::MiqAeServiceServiceTemplate.find(service_template.id) }
  end
  let(:root_object) { Spec::Support::MiqAeMockObject.new(root_hash) }
  let(:ae_service) do
    Spec::Support::MiqAeMockService.new(root_object).tap do |service|
      current_object = Spec::Support::MiqAeMockObject.new
      current_object.parent = root_object
      service.object = current_object
    end
  end

  shared_examples_for "#having only default value" do
    let(:default_desc_blank) { "<none>" }

    it "provides only default value to the resource group list" do
      described_class.new(ae_service).main

      expect(ae_service["values"]).to eq(nil => default_desc_blank)
    end
  end

  shared_examples_for "#having all of the resource groups" do
    let(:default_desc) { "<select>" }
    let(:rgroup1) { FactoryGirl.create(:resource_group) }
    let(:rgroup2) { FactoryGirl.create(:resource_group) }
    let(:ems) do
      FactoryGirl.create(:ems_azure, :resource_groups => [rgroup1, rgroup2])
    end

    it "finds all the resource groups and populates the list" do
      described_class.new(ae_service).main

      expect(ae_service["values"]).to include(
        nil          => default_desc,
        rgroup1.name => rgroup1.name,
        rgroup2.name => rgroup2.name)
    end
  end

  context "workspace has no service template" do
    let(:root_hash) { {} }

    it_behaves_like "#having only default value"
  end

  context "workspace has service template other than orchestration" do
    let(:service_template) { FactoryGirl.create(:service_template) }

    it_behaves_like "#having only default value"
  end

  context "workspace has orchestration service template" do
    context 'with orchestration_manager' do
      let(:service_template) do
        FactoryGirl.create(:service_template_orchestration, :orchestration_manager => ems)
      end

      it_behaves_like "#having all of the resource groups"
    end

    context 'without orchestration_manager' do
      let(:service_template) do
        FactoryGirl.create(:service_template_orchestration)
      end

      it_behaves_like "#having only default value"
    end
  end

  context "workspace has orchestration service" do
    let(:root_hash) do
      { 'service_template' => MiqAeMethodService::MiqAeServiceService.find(service_template.id) }
    end

    context 'with orchestration_manager' do
      let(:service_template) do
        FactoryGirl.create(:service_orchestration, :orchestration_manager => ems)
      end

      it_behaves_like "#having all of the resource groups"
    end

    context 'without orchestration_manager' do
      let(:service_template) do
        FactoryGirl.create(:service_orchestration)
      end

      it_behaves_like "#having only default value"
    end
  end
end
