describe DatabaseBackup do
  context "with basic db settings" do
    before(:each) do
      DatabaseBackup.instance_variable_set(:@backup_supported, nil)
      @db_opts = {:username => "root", :password => "smartvm", :name => "postgresl", :host => "localhost", :database => "vmdb"}
    end

    it "should support backup with internal pg" do
      @db_opts[:name] = "internal"
      allow_any_instance_of(MiqDbConfig).to receive(:options).and_return(@db_opts)
      expect(DatabaseBackup.backup_supported?).to be_truthy
    end

    it "should support backup with pg" do
      @db_opts[:name] = "postgresql"
      allow_any_instance_of(MiqDbConfig).to receive(:options).and_return(@db_opts)
      expect(DatabaseBackup.backup_supported?).to be_truthy
    end

    it "should support backup with external pg" do
      @db_opts[:name] = "external_evm"
      allow_any_instance_of(MiqDbConfig).to receive(:options).and_return(@db_opts)
      expect(DatabaseBackup.backup_supported?).to be_truthy
    end

    it "should not support backup with mysql" do
      @db_opts[:name] = "mysql"
      allow_any_instance_of(MiqDbConfig).to receive(:options).and_return(@db_opts)
      expect(DatabaseBackup.backup_supported?).not_to be_truthy
    end
  end

  context "region" do
    before(:each) do
      @region = FactoryGirl.create(:miq_region, :region => 3)
      allow(described_class).to receive_messages(:my_region_number => @region.region)
    end

    it "should set region_name based on my_region_number if database backup has a region" do
      backup = FactoryGirl.create(:database_backup)
      expect(backup.region_name).to eq("region_#{@region.region}")
    end

    it "should set region_name to region_0 if region is unknown" do
      # my_region_number => 0 if REGION file is missing or empty
      allow(described_class).to receive_messages(:my_region_number => 0)
      backup = FactoryGirl.create(:database_backup)
      expect(backup.region_name).to eq("region_0")
    end

    it "should set class method region_name to MiqRegion.my_region.region" do
      expect(DatabaseBackup.region_name).to eq("region_#{@region.region}")
    end
  end

  context "schedule" do
    before(:each) do
      EvmSpecHelper.local_miq_server

      @name = "adhoc schedule"
      @sanitized_name = "adhoc_schedule"
      @schedule = FactoryGirl.create(:miq_schedule, :name => @name)
    end

    it "should set schedule_name to schedule_unknown if database backup was not passed a valid schedule id" do
      backup = FactoryGirl.create(:database_backup)
      backup.instance_variable_set(:@schedule, nil)
      expect(backup.schedule_name).to eq("schedule_unknown")
    end

    it "should set schedule_name to a sanitized version of the schedule's name if database backup was passed a valid schedule id" do
      backup = FactoryGirl.create(:database_backup)
      backup.instance_variable_set(:@sch, @schedule)
      expect(backup.schedule_name).to eq(@sanitized_name)
    end
  end
end
