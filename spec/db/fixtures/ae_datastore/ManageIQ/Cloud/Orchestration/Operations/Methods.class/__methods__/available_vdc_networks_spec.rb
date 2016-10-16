require Rails.root.join('db/fixtures/ae_datastore/ManageIQ/Cloud/Orchestration/Operations/Methods.class/__methods__/available_vdc_networks').to_s

describe AvailableVdcNetworks do
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

    it "provides only the no VDC networks" do
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

    it "provides only the no VDC networks info" do
      described_class.new(ae_service).main

      expect(ae_service.object["values"]).to eq(nil => default_desc_none)
      expect(ae_service.object["default_value"]).to eq(nil)
    end
  end

  shared_examples "orchestration manager" do
    context "no VDC network" do
      let(:vapp_net1) { FactoryGirl.create(:cloud_network_vmware_vapp, :ems_ref => "vapp_net1") }
      let(:ems) do
        FactoryGirl.create(:ems_vmware_cloud) do |ems|
          ems.cloud_networks << vapp_net1
        end
      end

      it "provides only the no VDC network info" do
        described_class.new(ae_service).main

        expect(ae_service.object["values"]).to eq(nil => default_desc_none)
        expect(ae_service.object["default_value"]).to eq(nil)
      end
    end

    context "single VDC network" do
      let(:vdc_net1) { FactoryGirl.create(:cloud_network_vmware_vdc, :ems_ref => "ref1") }
      let(:ems) do
        FactoryGirl.create(:ems_vmware_cloud) do |ems|
          ems.cloud_networks << vdc_net1
        end
      end

      it "finds the single VDC network and populates the list" do
        described_class.new(ae_service).main

        expect(ae_service.object["values"]).to include(
          nil              => default_desc_multiple,
          vdc_net1.ems_ref => vdc_net1.name)
        expect(ae_service.object["default_value"]).to eq(nil)
      end
    end

    context "with multiple VDC networks" do
      let(:vdc_net2) { FactoryGirl.create(:cloud_network_vmware_vdc, :ems_ref => "ref2") }
      let(:vdc_net3) { FactoryGirl.create(:cloud_network_vmware_vdc, :ems_ref => "ref3") }
      let(:ems) do
        FactoryGirl.create(:ems_vmware_cloud) do |ems|
          ems.cloud_networks << vdc_net2
          ems.cloud_networks << vdc_net3
        end
      end

      it "finds all the VDC networks and populates the list" do
        described_class.new(ae_service).main

        expect(ae_service.object["values"]).to include(
          nil              => default_desc_multiple,
          vdc_net2.ems_ref => vdc_net2.name,
          vdc_net3.ems_ref => vdc_net3.name,
        )
        expect(ae_service.object["default_value"]).to eq(nil)
      end
    end

    context "with VDC and vApp networks" do
      let(:vdc_net4) { FactoryGirl.create(:cloud_network_vmware_vdc, :ems_ref => "ref4") }
      let(:vdc_net5) { FactoryGirl.create(:cloud_network_vmware_vdc, :ems_ref => "ref5") }
      let(:vapp_net2) { FactoryGirl.create(:cloud_network_vmware_vapp, :ems_ref => "vapp_net2") }
      let(:ems) do
        FactoryGirl.create(:ems_vmware_cloud) do |ems|
          ems.cloud_networks << vdc_net4
          ems.cloud_networks << vdc_net5
          ems.cloud_networks << vapp_net2
        end
      end

      it "finds only the VDC networks and populates the list" do
        described_class.new(ae_service).main

        expect(ae_service.object["values"]).to include(
          nil              => default_desc_multiple,
          vdc_net4.ems_ref => vdc_net4.name,
          vdc_net5.ems_ref => vdc_net5.name,
        )
        expect(ae_service.object["values"]).not_to include(vapp_net2.ems_ref => vapp_net2.name)
        expect(ae_service.object["default_value"]).to eq(nil)
      end
    end

    context "does not exist" do
      let(:ems) { nil }

      it "provides only the default value to the VDC list" do
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
