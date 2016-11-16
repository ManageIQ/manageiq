require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/Cloud/Orchestration/' \
                        'Operations/Methods.class/__methods__/available_tenants').to_s

describe ManageIQ::Automate::Cloud::Orchestration::Operations::AvailableTenants do
  let(:tenant1) { FactoryGirl.create(:cloud_tenant) }
  let(:tenant2) { FactoryGirl.create(:cloud_tenant) }
  let(:ems) { FactoryGirl.create(:ems_openstack, :cloud_tenants => [tenant1, tenant2]) }
  let(:service_template_no_ems) do
    FactoryGirl.create(:service_template_orchestration)
  end
  let(:service_template) do
    FactoryGirl.create(:service_template_orchestration, :orchestration_manager => ems)
  end
  let(:service_no_ems) do
    FactoryGirl.create(:service_orchestration)
  end
  let(:service) do
    FactoryGirl.create(:service_orchestration, :orchestration_manager => ems)
  end
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

  context "workspace has no service template" do
    let(:root_hash) { {} }
    it "provides only default value to the tenant list" do
      described_class.new(ae_service).main

      expect(ae_service["values"]).to eq(nil => "<default>")
    end
  end

  context "workspace has service template other than orchestration" do
    let(:service_template) { FactoryGirl.create(:service_template) }

    it "provides only default value to the tenant list" do
      described_class.new(ae_service).main

      expect(ae_service["values"]).to eq(nil => "<default>")
    end
  end

  context "workspace has orchestration service template" do
    it "finds all the tenants and populates the list" do
      described_class.new(ae_service).main

      expect(ae_service["values"]).to include(
        nil          => "<default>",
        tenant1.name => tenant1.name,
        tenant2.name => tenant2.name
      )
    end
  end

  context "workspace has orchestration service template without ems" do
    let(:root_hash) do
      { 'service_template' => MiqAeMethodService::MiqAeServiceServiceTemplate.find(service_template_no_ems.id) }
    end

    it "provides only default value to the tenant list if orchestration manager does not exist" do
      described_class.new(ae_service).main

      expect(ae_service["values"]).to eq(nil => "<default>")
    end
  end

  context "workspace has orchestration service" do
    let(:root_hash) do
      { 'service_template' => MiqAeMethodService::MiqAeServiceService.find(service.id) }
    end

    it "finds all the tenants and populates the list" do
      described_class.new(ae_service).main

      expect(ae_service["values"]).to include(
        nil          => "<default>",
        tenant1.name => tenant1.name,
        tenant2.name => tenant2.name
      )
    end
  end

  context "workspace has orchestration service template without ems" do
    let(:root_hash) do
      { 'service_template' => MiqAeMethodService::MiqAeServiceService.find(service_no_ems.id) }
    end

    it "provides only default value to the tenant list if orchestration manager does not exist" do
      described_class.new(ae_service).main

      expect(ae_service["values"]).to eq(nil => "<default>")
    end
  end
end
