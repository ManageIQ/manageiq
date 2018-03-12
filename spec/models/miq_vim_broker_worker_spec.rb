describe MiqVimBrokerWorker do
  context ".emses_to_monitor" do
    it "detects emses" do
      @zone = EvmSpecHelper.local_miq_server.zone
      FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone)
      FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone)
      allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive_messages(:authentication_status_ok? => true)

      expect(described_class.emses_to_monitor).to match_array @zone.ext_management_systems
    end
  end

  context ".has_required_role_configured?" do
    before do
      FactoryGirl.create(:server_role, :name => 'ems_operations')
      my_server = EvmSpecHelper.local_miq_server
      my_server.update_attributes(:role => "ems_operations")
      my_server.activate_roles("ems_operations")
      @zone = my_server.zone
    end

    it "should not start the worker without an ems" do
      expect(described_class.has_required_role_configured?).to be_truthy
    end
  end

  context ".has_required_role?" do
    before do
      FactoryGirl.create(:server_role, :name => 'ems_operations')
      my_server = EvmSpecHelper.local_miq_server
      my_server.update_attributes(:role => "ems_operations")
      my_server.activate_roles("ems_operations")
      @zone = my_server.zone
    end

    it "should not start the worker without an ems" do
      expect(described_class.has_required_role?).to be_falsey
    end

    it "should start the worker with an ems" do
      allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive_messages(:authentication_status_ok? => true)
      FactoryGirl.create(:ems_vmware_with_authentication, :zone => @zone)
      expect(described_class.has_required_role?).to be_truthy
    end
  end

  context "update_driven_refresh" do
    before do
      stub_settings_merge(
        :prototype => {
          :ems_vmware => {
            :update_driven_refresh => true
          }
        }
      )
    end

    it ".required_roles" do
      expect(described_class.required_roles.call).not_to include('ems_inventory')
    end
  end

  context "standard refresh" do
    before do
      stub_settings_merge(
        :prototype => {
          :ems_vmware => {
            :update_driven_refresh => false
          }
        }
      )
    end

    it ".required_roles" do
      expect(described_class.required_roles.call).to include('ems_inventory')
    end
  end
end
