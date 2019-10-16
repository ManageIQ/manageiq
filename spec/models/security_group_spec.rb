describe SecurityGroup do
  describe ".non_cloud_network" do
    let(:provider) { FactoryBot.create(:ems_amazon) }

    before do
      @sg1 = FactoryBot.create(:security_group,
                               :ext_management_system => provider.network_manager,
                               :cloud_network         => FactoryBot.create(:cloud_network))
      @sg2 = FactoryBot.create(:security_group,
                               :ext_management_system => provider.network_manager)
    end

    it "calculates in the database" do
      expect(SecurityGroup.non_cloud_network).to eq([@sg2])
    end
  end

  describe "#total_vms" do
    it "counts vms" do
      sg = FactoryBot.create(:security_group)

      2.times do
        vm = FactoryBot.create(:vm_amazon)
        FactoryBot.create(:network_port_openstack,
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
