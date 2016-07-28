describe SecurityGroup do
  before do
    provider = FactoryGirl.create(:ems_amazon)
    cn       = FactoryGirl.create(:cloud_network)
    @sg1      = FactoryGirl.create(:security_group, :name => "sq_1", :ext_management_system => provider, :cloud_network => cn)
    @sg2      = FactoryGirl.create(:security_group, :name => "sq_1", :ext_management_system => provider)
  end

  it ".non_cloud_network" do
    expect(SecurityGroup.non_cloud_network).to eq([@sg2])
  end

  describe "#total_vms" do
    it "counts vms" do
      sg = FactoryGirl.create(:security_group)

      2.times do
        vm = FactoryGirl.create(:vm_amazon)
        FactoryGirl.create(:network_port_openstack,
                           :device          => vm,
                           :security_groups => [sg])
      end
      expect(sg.reload.total_vms).to eq(2)
    end

    it "doesnt support sql" do
      expect(SecurityGroup.attribute_supported_by_sql?(:total_vms)).to be false
    end
  end
end
