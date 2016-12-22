module MiqAeServiceNetworkRouterOpenstackSpec
  describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_NetworkManager_NetworkRouter do
    it "#update_network_router" do
      expect(described_class.instance_methods).to include(:update_network_router)
    end

    it "#delete_network_router" do
      expect(described_class.instance_methods).to include(:delete_network_router)
    end

    it "#add_interface" do
      expect(described_class.instance_methods).to include(:add_interface)
    end

    it "#remove_interface" do
      expect(described_class.instance_methods).to include(:remove_interface)
    end
  end
end
