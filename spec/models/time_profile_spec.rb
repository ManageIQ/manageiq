RSpec.describe TimeProfile do
  before do
    @server = EvmSpecHelper.local_miq_server
    @ems    = FactoryBot.create(:ems_vmware, :zone => @server.zone)
  end

  it "will default to the correct profile values" do
    t = TimeProfile.new
    expect(t.days).to eq(TimeProfile::ALL_DAYS)
    expect(t.hours).to eq(TimeProfile::ALL_HOURS)
    expect(t.tz).to be_nil
  end

  describe "#default?" do
    it "with a default profile" do
      tp = TimeProfile.seed
      expect(tp).to be_default
    end

    it "with a non-default profile" do
      tp = FactoryBot.create(:time_profile, :tz => "Hawaii")
      expect(tp).to_not be_default
    end
  end

  context "will seed the database" do
    before do
      TimeProfile.seed
    end

    it do
      t = TimeProfile.first
      expect(t.days).to eq(TimeProfile::ALL_DAYS)
      expect(t.hours).to eq(TimeProfile::ALL_HOURS)
      expect(t.tz).to eq(TimeProfile::DEFAULT_TZ)
      expect(t).to be_entire_tz
    end

    it "but not reseed when called twice" do
      TimeProfile.seed
      expect(TimeProfile.count).to eq(1)
      t = TimeProfile.first
      expect(t.days).to eq(TimeProfile::ALL_DAYS)
      expect(t.hours).to eq(TimeProfile::ALL_HOURS)
      expect(t.tz).to eq(TimeProfile::DEFAULT_TZ)
      expect(t).to be_entire_tz
    end
  end

  it "will return the correct values for tz_or_default" do
    t = TimeProfile.new
    expect(t.tz_or_default).to eq(TimeProfile::DEFAULT_TZ)
    expect(t.tz_or_default("Hawaii")).to eq("Hawaii")

    t.tz = "Hawaii"
    expect(t.tz).to eq("Hawaii")
    expect(t.tz_or_default).to eq("Hawaii")
    expect(t.tz_or_default("Alaska")).to eq("Hawaii")
  end

  it "will not rollup daily performances on create if rollups are disabled" do
    FactoryBot.create(:time_profile)
    assert_nothing_queued
  end

  context "with an existing time profile with rollups disabled" do
    before do
      @tp = FactoryBot.create(:time_profile)
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
    @tp = FactoryBot.create(:time_profile_with_rollup)
    assert_rebuild_daily_queued
  end

  context "with an existing time profile with rollups enabled" do
    before do
      @tp = FactoryBot.create(:time_profile_with_rollup)
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
    before do
      TimeProfile.seed
    end

    it "gets time profiles for user and global default timeprofile" do
      tp = TimeProfile.find_by(:description => TimeProfile::DEFAULT_TZ)
      tp.profile_type = "global"
      tp.save
      FactoryBot.create(:time_profile,
                         :description          => "test1",
                         :profile_type         => "user",
                         :profile_key          => "some_user",
                         :rollup_daily_metrics => true)

      FactoryBot.create(:time_profile,
                         :description          => "test2",
                         :profile_type         => "user",
                         :profile_key          => "foo",
                         :rollup_daily_metrics => true)
      tp = TimeProfile.profiles_for_user("foo", MiqRegion.my_region_number)
      expect(tp.count).to eq(2)
    end
  end

  context "profile_for_user_tz" do
    before do
      TimeProfile.seed
    end

    it "gets time profiles that matches user's tz and marked for daily Rollup" do
      FactoryBot.create(:time_profile,
                         :description          => "test1",
                         :profile_type         => "user",
                         :profile_key          => "some_user",
                         :tz                   => "other_tz",
                         :rollup_daily_metrics => true)

      FactoryBot.create(:time_profile,
                         :description          => "test2",
                         :profile_type         => "user",
                         :profile_key          => "foo",
                         :tz                   => "foo_tz",
                         :rollup_daily_metrics => true)
      tp = TimeProfile.profile_for_user_tz("foo", "foo_tz")
      expect(tp.description).to eq("test2")
    end
  end

  describe "#profile_for_each_region" do
    it "returns none for a non rollup metric" do
      tp = FactoryBot.create(:time_profile, :rollup_daily_metrics => false)

      expect(tp.profile_for_each_region).to eq([])
    end

    it "returns unique entries" do
      tp1a = FactoryBot.create(:time_profile_with_rollup, :id => id_in_region(5, 1))
      tp1b = FactoryBot.create(:time_profile_with_rollup, :id => id_in_region(5, 2))
      FactoryBot.create(:time_profile_with_rollup, :days => [1, 2], :id => id_in_region(5, 3))
      FactoryBot.create(:time_profile, :rollup_daily_metrics => false, :id => id_in_region(5, 4))
      tp2 = FactoryBot.create(:time_profile_with_rollup, :id => id_in_region(6, 1))
      FactoryBot.create(:time_profile_with_rollup, :days => [1, 2], :id => id_in_region(6, 2))
      FactoryBot.create(:time_profile, :rollup_daily_metrics => false, :id => id_in_region(6, 3))

      results = tp1a.profile_for_each_region
      expect(results.size).to eq(2)
      expect(results.map(&:region_id)).to match_array([5, 6])
      expect(results.include?(tp1a) || results.include?(tp1b)).to be true
      expect(results).to include(tp2)
    end
  end

  describe ".all_timezones" do
    it "works with seeds" do
      FactoryBot.create(:time_profile, :tz => "tz")
      FactoryBot.create(:time_profile, :tz => "tz")
      FactoryBot.create(:time_profile, :tz => "other_tz")

      expect(TimeProfile.all_timezones).to match_array(%w(tz other_tz))
    end
  end

  describe ".find_all_with_entire_tz" do
    it "only returns profiles with all days" do
      FactoryBot.create(:time_profile, :days => [1, 2])
      tp = FactoryBot.create(:time_profile)

      expect(TimeProfile.find_all_with_entire_tz).to eq([tp])
    end
  end

  describe ".profile_for_user_tz" do
    it "finds global profiles" do
      FactoryBot.create(:time_profile_with_rollup, :tz => "good", :profile_type => "global")
      expect(TimeProfile.profile_for_user_tz(1, "good")).to be_truthy
    end

    it "finds user profiles" do
      FactoryBot.create(:time_profile_with_rollup, :tz => "good", :profile_type => "user", :profile_key => 1)
      expect(TimeProfile.profile_for_user_tz(1, "good")).to be_truthy
    end

    it "skips invalid records" do
      FactoryBot.create(:time_profile_with_rollup, :tz => "bad", :profile_type => "global")
      FactoryBot.create(:time_profile, :tz => "good", :profile_type => "global", :rollup_daily_metrics => false)
      FactoryBot.create(:time_profile_with_rollup, :tz => "good", :profile_type => "user", :profile_key => "2")

      expect(TimeProfile.profile_for_user_tz(1, "good")).not_to be
    end
  end

  private

  def id_in_region(region, id)
    region * MiqRegion::DEFAULT_RAILS_SEQUENCE_FACTOR + id
  end

  def assert_rebuild_daily_queued
    q_all = MiqQueue.all
    expect(q_all.length).to eq(1)
    expect(q_all[0].class_name).to eq("TimeProfile")
    expect(q_all[0].instance_id).to eq(@tp.id)
    expect(q_all[0].method_name).to eq("rebuild_daily_metrics")
  end

  def assert_destroy_queued
    q_all = MiqQueue.all
    expect(q_all.length).to eq(1)
    expect(q_all[0].class_name).to eq("TimeProfile")
    expect(q_all[0].instance_id).to eq(@tp.id)
    expect(q_all[0].method_name).to eq("destroy_metric_rollups")
  end

  def assert_nothing_queued
    expect(MiqQueue.count).to eq(0)
  end
end
