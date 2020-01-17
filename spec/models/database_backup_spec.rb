RSpec.describe DatabaseBackup do
  context "region" do
    let!(:region) { FactoryBot.create(:miq_region, :region => 3) }

    before do
      allow(described_class).to receive_messages(:my_region_number => region.region)
    end

    it "should set region_name based on my_region_number if database backup has a region" do
      backup = FactoryBot.create(:database_backup)
      expect(backup.region_name).to eq("region_#{region.region}")
    end

    it "should set region_name to region_0 if region is unknown" do
      # my_region_number => 0 if REGION file is missing or empty
      allow(described_class).to receive_messages(:my_region_number => 0)
      backup = FactoryBot.create(:database_backup)
      expect(backup.region_name).to eq("region_0")
    end

    it "should set class method region_name to MiqRegion.my_region.region" do
      expect(DatabaseBackup.region_name).to eq("region_#{region.region}")
    end
  end

  context "schedule" do
    before do
      EvmSpecHelper.local_miq_server

      @name = "adhoc schedule"
      @sanitized_name = "adhoc_schedule"
      @schedule = FactoryBot.create(:miq_schedule, :name => @name)
    end

    it "should set schedule_name to schedule_unknown if database backup was not passed a valid schedule id" do
      backup = FactoryBot.create(:database_backup)
      backup.instance_variable_set(:@schedule, nil)
      expect(backup.schedule_name).to eq("schedule_unknown")
    end

    it "should set schedule_name to a sanitized version of the schedule's name if database backup was passed a valid schedule id" do
      backup = FactoryBot.create(:database_backup)
      backup.instance_variable_set(:@sch, @schedule)
      expect(backup.schedule_name).to eq(@sanitized_name)
    end
  end
end
