RSpec.describe SystemService do
  describe ".svc_type" do
    it "has nice names" do
      ss = FactoryBot.build(:system_service, :svc_type => "4")
      expect(ss.svc_type).to eq("Service Adapter")
    end

    it "has falls back to numeric name" do
      ss = FactoryBot.build(:system_service, :svc_type => "5")
      expect(ss.svc_type).to eq("5")
    end

    it "works with find" do
      ss = FactoryBot.create(:system_service, :svc_type => "4")
      expect(SystemService.find(ss.id).svc_type).to eq("Service Adapter")
    end
  end

  describe ".start" do
    it "has nice names" do
      ss = FactoryBot.build(:system_service, :start => "4")
      expect(ss.start).to eq("Disabled")
    end

    it "has falls back to numeric name" do
      ss = FactoryBot.build(:system_service, :start => "9")
      expect(ss.start).to eq("9")
    end
    it "works with find" do
      ss = FactoryBot.create(:system_service, :start => "4")
      expect(SystemService.find(ss.id).start).to eq("Disabled")
    end
  end
end
