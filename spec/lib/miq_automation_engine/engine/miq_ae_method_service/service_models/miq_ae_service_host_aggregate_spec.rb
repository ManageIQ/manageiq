
module MiqAeServiceHostAggregateSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceHostAggregate do
    before(:each) do
      @host_aggregate          = FactoryGirl.create(:host_aggregate, :name => "aggregate1")
      @service_host_aggregate  = MiqAeMethodService::MiqAeServiceHostAggregate.find(@host_aggregate.id)
    end

    it "check values" do
      expect(@service_host_aggregate.name).to eq("aggregate1")
      expect(@service_host_aggregate).to be_kind_of(MiqAeMethodService::MiqAeServiceHostAggregate)
    end

    it "#ext_management_system" do
      expect(described_class.instance_methods).to include(:ext_management_system)
    end

    it "#hosts" do
      expect(described_class.instance_methods).to include(:hosts)
    end
  end
end
