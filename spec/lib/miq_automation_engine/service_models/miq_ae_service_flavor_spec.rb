
module MiqAeServiceFlavorSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceFlavor do
    before(:each) do
      @flavor                 = FactoryGirl.create(:flavor, :name => "small", :description => "really small", :cpus => 1, :memory => 2.gigabytes)
      @service_flavor         = MiqAeMethodService::MiqAeServiceFlavor.find(@flavor.id)
    end

    it "check values" do
      expect(@service_flavor.name).to eq("small")
      expect(@service_flavor.description).to eq("really small")
      expect(@service_flavor.cpus).to eq(1)
      expect(@service_flavor.memory).to eq(2.gigabytes)
      expect(@service_flavor).to be_kind_of(MiqAeMethodService::MiqAeServiceFlavor)
    end

    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#vms" do
      expect(described_class.instance_methods).to include(:vms)
    end
  end
end
