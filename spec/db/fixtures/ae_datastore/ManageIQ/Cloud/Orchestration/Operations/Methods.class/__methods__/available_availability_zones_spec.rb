require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/Cloud/Orchestration/Operations/Methods.class/__methods__/available_availability_zones').to_s

describe ManageIQ::Automate::Cloud::Orchestration::Operations::AvailableAvailabilityZones do
  let(:default_desc_none) { "<none>" }
  let(:default_desc_multiple) { "<select>" }
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

    it "provides only the no availability zones info" do
      described_class.new(ae_service).main

      expect(ae_service.object["values"]).to eq(nil => default_desc_none)
      expect(ae_service.object["default_value"]).to eq(nil)
    end
  end

  context "workspace has service template other than orchestration" do
    let(:service_template) { FactoryGirl.create(:service_template) }
    let(:root_hash) do
      { 'service_template' => MiqAeMethodService::MiqAeServiceServiceTemplate.find(service_template.id) }
    end

    it "provides only the no availability zones info" do
      described_class.new(ae_service).main

      expect(ae_service.object["values"]).to eq(nil => default_desc_none)
      expect(ae_service.object["default_value"]).to eq(nil)
    end
  end

  shared_examples_for "orchestration manager" do
    context "with a single availability zone" do
      let(:az1) { FactoryGirl.create(:availability_zone, :ems_ref => "ref1") }
      let(:ems) { FactoryGirl.create(:ems_vmware_cloud, :availability_zones => [az1]) }

      it "finds the single availability zone and populates the list" do
        described_class.new(ae_service).main

        expect(ae_service.object["values"]).to eq(az1.ems_ref => az1.name)
        expect(ae_service.object["default_value"]).to eq(az1.ems_ref)
      end
    end

    context "with multiple availability zones" do
      let(:az2) { FactoryGirl.create(:availability_zone, :ems_ref => "ref2") }
      let(:az3) { FactoryGirl.create(:availability_zone, :ems_ref => "ref3") }
      let(:ems) { FactoryGirl.create(:ems_vmware_cloud, :availability_zones => [az2, az3]) }

      it "finds all the availability zones and populates the list" do
        described_class.new(ae_service).main

        expect(ae_service.object["values"]).to include(
          nil         => default_desc_multiple,
          az2.ems_ref => az2.name,
          az3.ems_ref => az3.name
        )
        expect(ae_service.object["default_value"]).to eq(nil)
      end
    end

    context "does not exists" do
      let(:ems) { nil }

      it "provides only default value to the availability zones list" do
        described_class.new(ae_service).main

        expect(ae_service.object["values"]).to eq(nil => default_desc_none)
        expect(ae_service.object["default_value"]).to eq(nil)
      end
    end
  end

  describe "workspace has orchestration service template" do
    let(:service_template) do
      FactoryGirl.create(:service_template_orchestration, :orchestration_manager => ems)
    end

    let(:root_hash) do
      { 'service_template' => MiqAeMethodService::MiqAeServiceServiceTemplate.find(service_template.id) }
    end

    it_behaves_like "orchestration manager"
  end

  context "workspace has orchestration service" do
    let(:service_orchestration) do
      FactoryGirl.create(:service_orchestration, :orchestration_manager => ems)
    end

    let(:root_hash) do
      { 'service' => MiqAeMethodService::MiqAeServiceServiceOrchestration.find(service_orchestration.id) }
    end

    it_behaves_like "orchestration manager"
  end
end
