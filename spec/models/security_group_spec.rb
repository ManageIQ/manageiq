require "spec_helper"

describe SecurityGroup do

  before do
    provider = FactoryGirl.create(:ems_amazon)
    cn       = FactoryGirl.create(:cloud_network)
    @sg1      = FactoryGirl.create(:security_group, :name => "sq_1", :ext_management_system => provider, :cloud_network => cn)
    @sg2      = FactoryGirl.create(:security_group, :name => "sq_1", :ext_management_system => provider)
  end

  it ".non_cloud_network" do
    SecurityGroup.non_cloud_network.should == [@sg2]
  end
end
