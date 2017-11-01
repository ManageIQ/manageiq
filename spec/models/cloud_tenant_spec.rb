describe CloudTenant do
  it "#all_cloud_networks" do
    ems     = FactoryGirl.create(:ems_openstack)
    tenant1 = FactoryGirl.create(:cloud_tenant,  :ext_management_system => ems)
    tenant2 = FactoryGirl.create(:cloud_tenant,  :ext_management_system => ems)
    net1    = FactoryGirl.create(:cloud_network, :ext_management_system => ems.network_manager, :shared => true)
    net2    = FactoryGirl.create(:cloud_network, :ext_management_system => ems.network_manager, :cloud_tenant => tenant1)
    _net3   = FactoryGirl.create(:cloud_network, :ext_management_system => ems.network_manager, :cloud_tenant => tenant2)

    expect(tenant1.all_cloud_networks).to match_array([net1, net2])
  end

  describe "#generic_custom_buttons" do
    before do
      allow(CustomButton).to receive(:buttons_for).with("CloudTenant").and_return("this is a list of custom buttons")
    end

    it "returns all the custom buttons for cloud tenants" do
      expect(CloudTenant.new.generic_custom_buttons).to eq("this is a list of custom buttons")
    end
  end
end
