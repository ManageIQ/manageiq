require "spec_helper"

describe CloudTenant do
  it "#all_cloud_networks" do
    ems     = FactoryGirl.create(:ems_openstack)
    tenant1 = FactoryGirl.create(:cloud_tenant,  :ext_management_system => ems)
    tenant2 = FactoryGirl.create(:cloud_tenant,  :ext_management_system => ems)
    net1    = FactoryGirl.create(:cloud_network, :ext_management_system => ems, :shared => true)
    net2    = FactoryGirl.create(:cloud_network, :ext_management_system => ems, :cloud_tenant => tenant1)
    _net3   = FactoryGirl.create(:cloud_network, :ext_management_system => ems, :cloud_tenant => tenant2)

    expect(tenant1.all_cloud_networks).to match_array([net1, net2])
  end
end
