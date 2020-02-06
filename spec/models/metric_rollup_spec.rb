RSpec.describe MetricRollup do
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
      metric.update!(:cpu_usage_rate_average => 75.0)
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
        Tagging.includes(:taggable => {}).where('bogus_table.column = 1').references(:bogus_table).to_a
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

  describe ".v_pct_cpu_ready_delta_summation" do
    it "should return the correct values for Vm hourly" do
      pdata = {
        :resource_type             => "VmOrTemplate",
        :capture_interval_name     => "hourly",
        :intervals_in_rollup       => 180,
        :cpu_ready_delta_summation => 10_604.0,
        :cpu_used_delta_summation  => 401_296.0,
        :cpu_wait_delta_summation  => 6_709_070.0,
      }
      perf = MetricRollup.new(pdata)

      expect(perf.v_pct_cpu_ready_delta_summation).to eq(0.3)
      expect(perf.v_pct_cpu_used_delta_summation).to eq(11.1)
      expect(perf.v_pct_cpu_wait_delta_summation).to eq(186.4)
    end

    it "should return the correct values for Vm daily" do
      pdata = {
        :resource_type             => "VmOrTemplate",
        :capture_interval_name     => "daily",
        :intervals_in_rollup       => 24,
        :cpu_ready_delta_summation => 10_868.0833333333,
        :cpu_used_delta_summation  => 131_611.583333333,
        :cpu_wait_delta_summation  => 6_772_579.45833333,
      }
      perf = MetricRollup.new(pdata)

      expect(perf.v_pct_cpu_ready_delta_summation).to eq(0.3)
      expect(perf.v_pct_cpu_used_delta_summation).to eq(3.7)
      expect(perf.v_pct_cpu_wait_delta_summation).to eq(188.1)
    end

    it "should return the correct values for Host hourly" do
      pdata = {
        :resource_type             => "Host",
        :capture_interval_name     => "hourly",
        :intervals_in_rollup       => 179,
        :derived_vm_count_on       => 6,
        :cpu_ready_delta_summation => 54_281.0,
        :cpu_used_delta_summation  => 2_324_833.0,
        :cpu_wait_delta_summation  => 36_722_174.0,
      }
      perf = MetricRollup.new(pdata)

      expect(perf.v_pct_cpu_ready_delta_summation).to eq(0.3)
      expect(perf.v_pct_cpu_used_delta_summation).to eq(10.8)
      expect(perf.v_pct_cpu_wait_delta_summation).to eq(170.0)

      pdata[:derived_vm_count_on] = nil
      perf = MetricRollup.new(pdata)
      expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)

      pdata[:derived_vm_count_on] = 0
      perf = MetricRollup.new(pdata)
      expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)
    end

    it "should return the correct values for Host daily" do
      pdata = {
        :resource_type             => "Host",
        :capture_interval_name     => "daily",
        :intervals_in_rollup       => 24,
        :derived_vm_count_on       => 6,
        :cpu_ready_delta_summation => 50_579.1666666667,
        :cpu_used_delta_summation  => 2_180_869.375,
        :cpu_wait_delta_summation  => 36_918_805.4166667,
      }
      perf = MetricRollup.new(pdata)

      expect(perf.v_pct_cpu_ready_delta_summation).to eq(0.2)
      expect(perf.v_pct_cpu_used_delta_summation).to eq(10.1)
      expect(perf.v_pct_cpu_wait_delta_summation).to eq(170.9)

      pdata[:derived_vm_count_on] = nil
      perf = MetricRollup.new(pdata)
      expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)

      pdata[:derived_vm_count_on] = 0
      perf = MetricRollup.new(pdata)
      expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)
    end

    it "should return the correct values for Cluster hourly" do
      pdata = {
        :resource_type             => "EmsCluster",
        :capture_interval_name     => "hourly",
        :intervals_in_rollup       => nil,
        :derived_vm_count_on       => 10,
        :cpu_ready_delta_summation => 58_783.0,
        :cpu_used_delta_summation  => 3_668_409.0,
        :cpu_wait_delta_summation  => 60_426_340.0,
      }
      perf = MetricRollup.new(pdata)

      expect(perf.v_pct_cpu_ready_delta_summation).to eq(0.2)
      expect(perf.v_pct_cpu_used_delta_summation).to eq(10.2)
      expect(perf.v_pct_cpu_wait_delta_summation).to eq(167.9)

      pdata[:derived_vm_count_on] = nil
      perf = MetricRollup.new(pdata)
      expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)

      pdata[:derived_vm_count_on] = 0
      perf = MetricRollup.new(pdata)
      expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)
    end

    it "should return the correct values for Cluster daily" do
      pdata = {
        :resource_type             => "EmsCluster",
        :capture_interval_name     => "daily",
        :intervals_in_rollup       => 24,
        :derived_vm_count_on       => 10,
        :cpu_ready_delta_summation => 54_120.0833333333,
        :cpu_used_delta_summation  => 3_209_660.54166667,
        :cpu_wait_delta_summation  => 60_868_270.1666667,
      }
      perf = MetricRollup.new(pdata)

      expect(perf.v_pct_cpu_ready_delta_summation).to eq(0.2)
      expect(perf.v_pct_cpu_used_delta_summation).to eq(8.9)
      expect(perf.v_pct_cpu_wait_delta_summation).to eq(169.1)

      pdata[:derived_vm_count_on] = nil
      perf = MetricRollup.new(pdata)
      expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)

      pdata[:derived_vm_count_on] = 0
      perf = MetricRollup.new(pdata)
      expect(perf.v_pct_cpu_ready_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_used_delta_summation).to eq(0)
      expect(perf.v_pct_cpu_wait_delta_summation).to eq(0)
    end
  end
end
