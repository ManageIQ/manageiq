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
      2.times { sg.vms.create(FactoryGirl.attributes_for(:vm)) }
      expect(sg.reload.total_vms).to eq(2)
    end

    it "doesnt support sql" do
      expect(SecurityGroup.attribute_supported_by_sql?(:total_vms)).to be false
    end
  end
end
