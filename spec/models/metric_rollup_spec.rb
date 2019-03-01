describe MetricRollup do
  describe "metric_rollups view" do
    it "creates an object with an id" do
      metric = described_class.create!(:timestamp => Time.now.utc)
      expect(metric.id).to be > 0
    end

    it "initializes an object's id after save" do
      metric = described_class.new
      metric.timestamp = Time.now.utc
      metric.save!
      expect(metric.id).to be > 0
    end

    it "updates an existing object correctly" do
      metric = described_class.create!(:timestamp => Time.now.utc, :cpu_usage_rate_average => 50.0)
      old_id = metric.id
      metric.update_attributes!(:cpu_usage_rate_average => 75.0)
      expect(metric.id).to eq(old_id)
    end
  end

  context "test" do
    it "should not raise an error when a polymorphic reflection is included and references are specified in a query" do
      skip "until ActiveRecord is fixed"
      # TODO: A fix in ActiveRecord will make this test pass
      expect do
        MetricRollup.where(:id => 1)
          .includes(:resource => {}, :time_profile => {})
          .references(:time_profile => {}).last
      end.not_to raise_error

      # TODO: Also, there is a bug that exists in only the manageiq repo and not rails
      # TODO: that causes the error "ActiveRecord::ConfigurationError: nil"
      # TODO: instead of the expected "ActiveRecord::EagerLoadPolymorphicError" error.
      expect do
        Tagging.includes(:taggable => {}).where('bogus_table.column = 1').references(:bogus_table => {}).to_a
      end.to raise_error ActiveRecord::EagerLoadPolymorphicError
    end
  end

  context ".rollups_in_range" do
    before do
      @current = FactoryBot.create_list(:metric_rollup_vm_hr, 2)
      @past = FactoryBot.create_list(:metric_rollup_vm_hr, 2, :timestamp => Time.now.utc - 5.days)
    end

    it "returns rollups from the correct range" do
      rollups = described_class.rollups_in_range('VmOrTemplate', nil, 'hourly', Time.zone.today)

      expect(rollups.size).to eq(2)
      expect(rollups.pluck(:id)).to match_array(@current.pluck(:id))

      rollups = described_class.rollups_in_range('VmOrTemplate', nil, 'hourly', Time.zone.today - 5.days, Time.zone.today - 4.days)

      expect(rollups.size).to eq(2)
      expect(rollups.pluck(:id)).to match_array(@past.pluck(:id))

      rollups = described_class.rollups_in_range('VmOrTemplate', nil, 'hourly', Time.zone.today - 5.days)

      expect(rollups.size).to eq(4)
      expect(rollups.pluck(:id)).to match_array(@current.pluck(:id) + @past.pluck(:id))
    end
  end
end
