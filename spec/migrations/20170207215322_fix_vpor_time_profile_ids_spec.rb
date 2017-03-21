require_migration

describe FixVporTimeProfileIds do
  let(:vpor_stub)         { migration_stub(:VimPerformanceOperatingRange) }
  let(:time_profile_stub) { migration_stub(:TimeProfile) }

  migration_context :up do
    it "when the user has previously corrected TimeProfile ids" do
      tp = create_default_time_profile

      to_delete = vpor_stub.create!
      to_keep   = vpor_stub.create!(:time_profile_id => tp.id)

      migrate

      expect { to_delete.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(to_keep.reload).to be
    end

    it "when the user does not have previously corrected TimeProfile ids" do
      tp = create_default_time_profile

      to_update = vpor_stub.create!

      migrate

      expect(to_update.reload.time_profile_id).to eq(tp.id)
    end
  end

  def create_default_time_profile
    time_profile_stub.create!(
      :profile => {
        :tz    => time_profile_stub::DEFAULT_TZ,
        :days  => time_profile_stub::ALL_DAYS,
        :hours => time_profile_stub::ALL_HOURS
      },
      :rollup_daily_metrics => true
    )
  end
end
