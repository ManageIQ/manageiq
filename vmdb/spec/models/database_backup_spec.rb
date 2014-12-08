require "spec_helper"

describe DatabaseBackup do
  context "with basic db settings" do
    before(:each) do
      DatabaseBackup.instance_variable_set(:@backup_supported, nil)
      @db_opts = {:username => "root", :password => "smartvm", :name => "postgresl", :host => "localhost", :database => "vmdb"}
    end

    it "should support backup with internal pg" do
      @db_opts[:name] = "internal"
      MiqDbConfig.any_instance.stub(:options).and_return(@db_opts)
      DatabaseBackup.backup_supported?.should be_true
    end

    it "should support backup with pg" do
      @db_opts[:name] = "postgresql"
      MiqDbConfig.any_instance.stub(:options).and_return(@db_opts)
      DatabaseBackup.backup_supported?.should be_true
    end

    it "should support backup with external pg" do
      @db_opts[:name] = "external_evm"
      MiqDbConfig.any_instance.stub(:options).and_return(@db_opts)
      DatabaseBackup.backup_supported?.should be_true
    end

    it "should not support backup with mysql" do
      @db_opts[:name] = "mysql"
      MiqDbConfig.any_instance.stub(:options).and_return(@db_opts)
      DatabaseBackup.backup_supported?.should_not be_true
    end
  end

  context "region" do
    before(:each) do
      @region = FactoryGirl.create(:miq_region, :region => 3)
      described_class.stub(:my_region_number => @region.region)
    end

    it "should set region_name based on my_region_number if database backup has a region" do
      backup = FactoryGirl.create(:database_backup)
      backup.region_name.should == "region_#{@region.region}"
    end

    it "should set region_name to region_0 if region is unknown" do
      # my_region_number => 0 if REGION file is missing or empty
      described_class.stub(:my_region_number => 0)
      backup = FactoryGirl.create(:database_backup)
      backup.region_name.should == "region_0"
    end

    it "should set class method region_name to MiqRegion.my_region.region" do
      DatabaseBackup.region_name.should == "region_#{@region.region}"
    end
  end

  context "schedule" do
    before(:each) do
      @zone  = FactoryGirl.create(:zone)
      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@guid)
      @server = FactoryGirl.create(:miq_server, :zone => @zone, :guid => @guid)
      MiqServer.my_server_clear_cache

      @name = "adhoc schedule"
      @sanitized_name = "adhoc_schedule"
      @schedule = FactoryGirl.create(:miq_schedule, :name => @name)
    end

    it "should set schedule_name to schedule_unknown if database backup was not passed a valid schedule id" do
      backup = FactoryGirl.create(:database_backup)
      backup.instance_variable_set(:@schedule, nil)
      backup.schedule_name.should == "schedule_unknown"
    end

    it "should set schedule_name to a sanitized version of the schedule's name if database backup was passed a valid schedule id" do
      backup = FactoryGirl.create(:database_backup)
      backup.instance_variable_set(:@sch, @schedule)
      backup.schedule_name.should == @sanitized_name
    end
  end
end
