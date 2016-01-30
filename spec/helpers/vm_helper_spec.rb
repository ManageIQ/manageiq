# @record.operating_system && @record.operating_system.processes.maximum(:updated_on)

describe VmHelper do
  describe "#last_date_processes" do
    it "supports vm with os and processes" do
      server = FactoryGirl.build(:miq_server, :id => 99_999)
      operating_system = FactoryGirl.build(:operating_system)
      @record = FactoryGirl.create(:vm_vmware, :miq_server => server, :operating_system => operating_system)
      now = Time.now.utc
      operating_system.processes.create(:updated_on => 1.day.ago)
      operating_system.processes.create(:updated_on => now)
      operating_system.processes.create(:updated_on => 2.day.ago)
      expect(helper.last_date_processes).to be_within(1.second).of(now)
    end

    it "supports vm without an OS" do
      @record = FactoryGirl.create(:vm_vmware)
      expect(helper.last_date_processes).to be_nil
    end
  end
end
