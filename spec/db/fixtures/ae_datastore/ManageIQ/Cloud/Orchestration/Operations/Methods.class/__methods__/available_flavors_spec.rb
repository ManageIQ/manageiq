require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/Cloud/Orchestration/Operations' \
                        '/Methods.class/__methods__/available_flavors.rb').to_s

describe ManageIQ::Automate::Cloud::Orchestration::Operations::AvailableFlavors do
  let(:root_object) { Spec::Support::MiqAeMockObject.new(root_hash) }
  let(:root_hash) do
    { 'service_template' => MiqAeMethodService::MiqAeServiceServiceTemplate.find(service_template.id) }
  end
  let(:ae_service) do
    Spec::Support::MiqAeMockService.new(root_object).tap do |service|
      current_object = Spec::Support::MiqAeMockObject.new
      current_object.parent = root_object
      service.object = current_object
    end
  end

  shared_examples_for "#having only default value" do
    let(:default_desc_blank) { "<none>" }

    it "provides only default value to the flavor list" do
      described_class.new(ae_service).main

      expect(ae_service["values"]).to eq(nil => default_desc_blank)
      expect(ae_service["default_value"]).to be_nil
    end
  end

  shared_examples_for "#having all flavors" do |service_type|
    let(:default_desc) { "<select>" }
    let(:flavor1) { FactoryGirl.create(:flavor, :name => 'flavor1') }
    let(:flavor2) { FactoryGirl.create(:flavor, :name => 'flavor2') }
    let(:ems) { FactoryGirl.create(:ems_openstack, :flavors => [flavor1, flavor2]) }

    let(:svc_model_flavor1) do
      MiqAeMethodService::MiqAeServiceFlavor.find(flavor1.id)
    end

    let(:svc_model_flavor2) do
      MiqAeMethodService::MiqAeServiceFlavor.find(flavor2.id)
    end

    let(:svc_model_orchestration_manager) do
      MiqAeMethodService::MiqAeServiceExtManagementSystem.find(ems.id)
    end

    let(:svc_model_service) do
      root_hash["service_template"] || root_hash["service"]
    end

    it "finds all the flavors and populates the list" do
      allow(ae_service.root).to receive(:attributes)
        .and_return(service_type => svc_model_service)
      allow(svc_model_service).to receive(:orchestration_manager)
        .and_return(svc_model_orchestration_manager)
      allow(svc_model_orchestration_manager).to receive(:flavors)
        .and_return([svc_model_flavor1, svc_model_flavor2])
      described_class.new(ae_service).main

      expect(ae_service["values"]).to include(
        nil          => default_desc,
        flavor1.name => flavor1.name,
        flavor2.name => flavor2.name
      )
      expect(ae_service["default_value"]).to be_nil
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

      it_behaves_like "#having all flavors", "service_template"
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
      { 'service' => MiqAeMethodService::MiqAeServiceService.find(service.id) }
    end

    context 'with orchestration_manager' do
      let(:service) do
        FactoryGirl.create(:service_orchestration, :orchestration_manager => ems)
      end

      it_behaves_like "#having all flavors", "service"
    end

    context 'without orchestration_manager' do
      let(:service) do
        FactoryGirl.create(:service_orchestration)
      end

      it_behaves_like "#having only default value"
    end
  end
end
