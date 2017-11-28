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

  describe '#total_vms' do
    let(:ems)          { FactoryGirl.create(:ems_openstack) }
    let(:vm1)          { FactoryGirl.create(:vm_openstack, :ext_management_system => ems) }
    let(:vm2)          { FactoryGirl.create(:vm_openstack, :ext_management_system => nil) }
    let(:vms)          { [vm1, vm2] }
    let(:template)     { FactoryGirl.create(:miq_template) }
    let(:cloud_tenant) { FactoryGirl.create(:cloud_tenant, :ext_management_system => ems, :vms => vms, :miq_templates => [template]) }

    it 'counts only vms' do
      cloud_tenant.reload
      expect(cloud_tenant.vms.map(&:id)).to match_array([vm1.id])
      expect(cloud_tenant.total_vms).to eq(1)

      total_vms_from_select = CloudTenant.where(:id => cloud_tenant).select(:total_vms).first[:total_vms]
      expect(total_vms_from_select).to eq(1)
      expect(total_vms_from_select).to eq(cloud_tenant.total_vms)
      expect(cloud_tenant.vms_and_templates.count).to eq(3)
    end
  end
end
