RSpec.describe SecurityGroup do
  include Spec::Support::ArelHelper

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
    let(:sg) do
      FactoryBot.create(:security_group).tap do |sg|
        2.times { FactoryBot.create(:network_port_openstack, :device => FactoryBot.create(:vm_amazon), :security_groups => [sg]) }
      end.reload
    end

    it "calculates in ruby" do
      expect(sg.total_vms).to eq(2)
    end

    it "calculates in the database" do
      sg
      expect(virtual_column_sql_value(SecurityGroup, "total_vms")).to eq(2)
    end
  end
end
