describe MiqStorageMetric do
  let(:time) { Time.utc(2013, 4, 22, 8, 31) }

  describe ".purge_date" do
    it "using Fixnum" do
      stub_settings(:storage => {:metrics_history => {:token => 20}})
      Timecop.freeze(time) do
        expect(described_class.purge_date(:token)).to eq 20.days.ago.utc
      end
    end

    it "using Time Unit days" do
      stub_settings(:storage => {:metrics_history => {:token => "20.days"}})
      Timecop.freeze(time) do
        expect(described_class.purge_date(:token)).to eq 20.days.ago.utc
      end
    end

    it "using Time Unit minutes" do
      stub_settings(:storage => {:metrics_history => {:token => "20.minutes"}})
      Timecop.freeze(time) do
        expect(described_class.purge_date(:token)).to eq 20.minutes.ago.utc
      end
    end

    it "handles nill" do
      stub_server_configuration(:storage => {:metrics_history => {:token => nil}})
      Timecop.freeze(time) do
        expect(described_class.purge_date(:token)).to eq nil
      end
    end
  end

  describe '.sub_class_names' do
    it "works" do
      OntapAggregateMetric.create
      expect(MiqStorageMetric.sub_class_names).to eq(%w(OntapAggregateMetric))
    end
  end

  describe '.sub_classes' do
    it "works" do
      OntapAggregateMetric.create
      expect(MiqStorageMetric.sub_classes).to eq([OntapAggregateMetric])
    end
  end

  describe '.derived_metrics_class_names' do
    it "works" do
      OntapAggregateMetric.create
      expect(MiqStorageMetric.derived_metrics_class_names).to eq(%w(OntapAggregateDerivedMetric))
    end
  end

  describe '.derived_metrics_classes' do
    it "works" do
      OntapAggregateMetric.create
      expect(MiqStorageMetric.derived_metrics_classes).to eq([OntapAggregateDerivedMetric])
    end
  end

  describe '.metrics_rollup_class_names' do
    it "works" do
      OntapAggregateMetric.create
      expect(MiqStorageMetric.metrics_rollup_class_names).to match_array(%w(OntapAggregateMetricsRollup))
    end
  end

  describe '.metrics_rollup_classes' do
    it "works" do
      OntapAggregateMetric.create
      expect(MiqStorageMetric.metrics_rollup_classes).to match_array([OntapAggregateMetricsRollup])
    end
  end

  describe '.derived_metrics_class_name' do
    it "detects own classes" do
      OntapAggregateMetric.create
      expect(OntapAggregateMetric.derived_metrics_class_name).to eq("OntapAggregateDerivedMetric")
    end

    it "doesnt return other classes" do
      OntapAggregateMetric.create
      expect(MiqStorageMetric.derived_metrics_class_name).to be_nil
    end
  end

  describe '.derived_metrics_class' do
    it "works" do
      OntapAggregateMetric.create
      expect(OntapAggregateMetric.derived_metrics_class).to eq(OntapAggregateDerivedMetric)
    end
  end

  describe '#derived_metrics_class' do
    it "works" do
      OntapAggregateMetric.create
      expect(OntapAggregateMetric.new.derived_metrics_class).to eq(OntapAggregateDerivedMetric)
    end
  end

  describe '.metrics_rollup_class_name' do
    it "works" do
      OntapAggregateMetric.create
      expect(OntapAggregateMetric.metrics_rollup_class_name).to eq("OntapAggregateMetricsRollup")
    end
  end

  describe '.metrics_rollup_class' do
    it "works" do
      OntapAggregateMetric.create
      expect(OntapAggregateMetric.metrics_rollup_class).to eq(OntapAggregateMetricsRollup)
    end
  end

  describe '#metrics_rollup_class' do
    it "works" do
      OntapAggregateMetric.create
      expect(OntapAggregateMetric.new.metrics_rollup_class).to eq(OntapAggregateMetricsRollup)
    end
  end

  describe '.purge_all_timer' do
    it "works" do
      # just use default of derived: 4.hours, hourly: 6.months, daily: 6.months
      stub_server_configuration(:storage => {:metrics_history => {}})
      OntapAggregateMetric.create
      MiqStorageMetric.purge_all_timer
    end
  end

  describe '.metrics_rollup_by_rollup_type' do
    it "works" do
      met = OntapDiskMetric.create()
      rollups = 2.times.map { met.miq_metrics_rollups.create(:rollup_type => "hourly") }
      expect(met.metrics_rollups_by_rollup_type("hourly")).to match_array(rollups)
    end
  end
end
