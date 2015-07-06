
require "spec_helper"

module MiqAeServiceFlavorSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceFlavor do

    before(:each) do
      @flavor                 = FactoryGirl.create(:flavor, :name => "small", :description => "really small", :cpus => 1, :memory => 2.gigabytes)
      @service_flavor         = MiqAeMethodService::MiqAeServiceFlavor.find(@flavor.id)
    end

    it "check values" do
      @service_flavor.name.should        == "small"
      @service_flavor.description.should == "really small"
      @service_flavor.cpus.should        == 1
      @service_flavor.memory.should      == 2.gigabytes
      @service_flavor.should be_kind_of(MiqAeMethodService::MiqAeServiceFlavor)
    end

    it "#ext_management_system" do
      described_class.instance_methods.should include(:ext_management_system)
    end

    it "#vms" do
      described_class.instance_methods.should include(:vms)
    end
  end
end
