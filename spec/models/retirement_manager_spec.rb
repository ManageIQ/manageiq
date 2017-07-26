describe RetirementManager do
  describe "#check" do
    it "with retirement date, runs retirement checks" do
      _, _, zone = EvmSpecHelper.local_guid_miq_server_zone
      ems = FactoryGirl.create(:ems_network, :zone => zone)

      load_balancer = FactoryGirl.create(:load_balancer, :retires_on => Time.zone.today + 1.day, :ext_management_system => ems)
      FactoryGirl.create(:load_balancer, :retired => true)
      orchestration_stack = FactoryGirl.create(:orchestration_stack, :retires_on => Time.zone.today + 1.day, :ext_management_system => ems)
      FactoryGirl.create(:orchestration_stack, :retired => true)
      vm = FactoryGirl.create(:vm, :retires_on => Time.zone.today + 1.day, :ems_id => ems.id)
      FactoryGirl.create(:vm, :retired => true)
      service = FactoryGirl.create(:service, :retires_on => Time.zone.today + 1.day)
      FactoryGirl.create(:service, :retired => true)

      expect(RetirementManager.check).to match_array([load_balancer, orchestration_stack, vm, service])
    end
  end
end
