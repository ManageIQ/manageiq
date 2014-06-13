require "spec_helper"

describe TimeProfile do
  before(:each) do
    @guid   = MiqUUID.new_guid
    MiqServer.stub(:my_guid).and_return(@guid)

    @zone   = FactoryGirl.create(:zone)
    @server = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone)
    MiqServer.my_server_clear_cache

    @ems    = FactoryGirl.create(:ems_vmware, :zone => @zone)
    EvmSpecHelper.clear_caches
  end

  it "will default to the correct profile values" do
    t = TimeProfile.new
    t.days.should  == TimeProfile::ALL_DAYS
    t.hours.should == TimeProfile::ALL_HOURS
    t.tz.should    be_nil
  end

  context "will seed the database" do
    before(:each) do
      MiqRegion.seed
      TimeProfile.seed
    end

    it do
      t = TimeProfile.first
      t.days.should  == TimeProfile::ALL_DAYS
      t.hours.should == TimeProfile::ALL_HOURS
      t.tz.should    == TimeProfile::DEFAULT_TZ
      t.entire_tz?.should be_true
    end

    it "but not reseed when called twice" do
      TimeProfile.seed
      TimeProfile.count.should == 1
      t = TimeProfile.first
      t.days.should  == TimeProfile::ALL_DAYS
      t.hours.should == TimeProfile::ALL_HOURS
      t.tz.should    == TimeProfile::DEFAULT_TZ
      t.entire_tz?.should be_true
    end
  end

  it "will return the correct values for tz_or_default" do
    t = TimeProfile.new
    t.tz_or_default.should == TimeProfile::DEFAULT_TZ
    t.tz_or_default("Hawaii").should == "Hawaii"

    t.tz = "Hawaii"
    t.tz.should == "Hawaii"
    t.tz_or_default.should == "Hawaii"
    t.tz_or_default("Alaska").should == "Hawaii"
  end

  it "will not rollup daily performances on create if rollups are disabled" do
    FactoryGirl.create(:time_profile)
    assert_nothing_queued
  end

  context "with an existing time profile with rollups disabled" do
    before(:each) do
      @tp = FactoryGirl.create(:time_profile)
      MiqQueue.delete_all
    end

    it "will not rollup daily performances if any changes are made" do
      @tp.update_attribute(:description, "New Description")
      assert_nothing_queued

      @tp.update_attribute(:days, [1, 2])
      assert_nothing_queued
    end

    it "will rollup daily performances if rollups are enabled" do
      @tp.update_attribute(:rollup_daily_metrics, true)
      assert_rebuild_daily_queued
    end
  end

  it "will rollup daily performances on create if rollups are enabled" do
    @tp = FactoryGirl.create(:time_profile_with_rollup)
    assert_rebuild_daily_queued
  end

  context "with an existing time profile with rollups enabled" do
    before(:each) do
      @tp = FactoryGirl.create(:time_profile_with_rollup)
      MiqQueue.delete_all
    end

    it "will not rollup daily performances if non-profile changes are made" do
      @tp.update_attribute(:description, "New Description")
      assert_nothing_queued
    end

    it "will rollup daily performances if profile changes are made" do
      @tp.update_attribute(:days, [1, 2])
      assert_rebuild_daily_queued
    end

    it "will not rollup daily performances if rollups are disabled" do
      @tp.update_attribute(:rollup_daily_metrics, false)
      assert_destroy_queued
    end
  end

  context "profiles_for_user" do
    before(:each) do
      MiqRegion.seed
      TimeProfile.seed
    end

    it "gets time profiles for user and global default timeprofile" do
      tp = TimeProfile.find_by_description(TimeProfile::DEFAULT_TZ)
      tp.profile_type = "global"
      tp.save
      FactoryGirl.create(:time_profile,
                         :description          => "test1",
                         :profile_type         => "user",
                         :profile_key          => "some_user",
                         :rollup_daily_metrics => true)

      FactoryGirl.create(:time_profile,
                         :description          => "test2",
                         :profile_type         => "user",
                         :profile_key          => "foo",
                         :rollup_daily_metrics => true)
      tp = TimeProfile.profiles_for_user("foo", MiqRegion.my_region_number)
      tp.count.should == 2
    end
  end

  context "profile_for_user_tz" do
    before(:each) do
      MiqRegion.seed
      TimeProfile.seed
    end

    it "gets time profiles that matches user's tz and marked for daily Rollup" do
      FactoryGirl.create(:time_profile,
                         :description          => "test1",
                         :profile_type         => "user",
                         :profile_key          => "some_user",
                         :tz                   => "other_tz",
                         :rollup_daily_metrics => true)

      FactoryGirl.create(:time_profile,
                         :description          => "test2",
                         :profile_type         => "user",
                         :profile_key          => "foo",
                         :tz                   => "foo_tz",
                         :rollup_daily_metrics => true)
      tp = TimeProfile.profile_for_user_tz("foo", "foo_tz")
      tp.description.should == "test2"
    end
  end

  def assert_rebuild_daily_queued
    q_all = MiqQueue.all
    q_all.length.should == 1
    q_all[0].class_name.should  == "TimeProfile"
    q_all[0].instance_id.should == @tp.id
    q_all[0].method_name.should == "rebuild_daily_metrics"
  end

  def assert_destroy_queued
    q_all = MiqQueue.all
    q_all.length.should == 1
    q_all[0].class_name.should  == "TimeProfile"
    q_all[0].instance_id.should == @tp.id
    q_all[0].method_name.should == "destroy_metric_rollups"
  end

  def assert_nothing_queued
    MiqQueue.count.should == 0
  end
end
