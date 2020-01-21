describe VmdbIndex do
  context "#capture_metrics" do
    let(:index) { FactoryBot.create(:vmdb_index, :name => "accounts_pkey") }

    it "creates a vmdb_metrics record" do
      # The first capture just gets the raw data
      index.capture_metrics
      expect(index.vmdb_metrics).to be_empty
      expect(index.prior_raw_metrics).to_not be_nil

      # The next capture starts creating the metrics rows
      index.capture_metrics
      expect(index.vmdb_metrics.count).to eq(1)

      metric = index.vmdb_metrics.first

      # Verify the column contents
      columns = %w( rows pages otta percent_bloat wasted_bytes timestamp )
      columns.each do |column|
        expect(metric.send(column)).to_not be_nil
      end

      # Verify the non-index columns are nil
      columns = %w(
        table_scans sequential_rows_read rows_inserted rows_updated rows_deleted
        rows_hot_updated rows_live rows_dead
      )
      columns.each do |column|
        expect(metric.send(column)).to be_nil
      end
    end
  end

  context "#rollup_metrics" do
    let(:db)    { FactoryBot.create(:vmdb_database) }
    let(:table) { FactoryBot.create(:vmdb_table_evm, :vmdb_database => db, :name => "accounts") }
    let(:index) { FactoryBot.create(:vmdb_index, :vmdb_table => table, :name => "accounts_pkey") }

    before do
      ts = Time.gm(2012, 8, 15, 10, 00, 01)         # Need specific date in order to keep track of rollup data...

      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 50.hours, :rows => 0,   :size => 0,    :wasted_bytes =>  0, :percent_bloat => 0.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 49.hours, :rows => 10,  :size => 100,  :wasted_bytes =>  2, :percent_bloat => 0.2)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 48.hours, :rows => 10,  :size => 100,  :wasted_bytes =>  2, :percent_bloat => 0.2)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 47.hours, :rows => 20,  :size => 200,  :wasted_bytes =>  4, :percent_bloat => 0.4)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 46.hours, :rows => 20,  :size => 200,  :wasted_bytes =>  4, :percent_bloat => 0.4)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 45.hours, :rows => 20,  :size => 200,  :wasted_bytes =>  4, :percent_bloat => 0.4)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 44.hours, :rows => 30,  :size => 300,  :wasted_bytes =>  6, :percent_bloat => 0.5)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 43.hours, :rows => 40,  :size => 400,  :wasted_bytes =>  8, :percent_bloat => 0.6)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 42.hours, :rows => 50,  :size => 500,  :wasted_bytes => 10, :percent_bloat => 0.7)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 41.hours, :rows => 60,  :size => 600,  :wasted_bytes => 12, :percent_bloat => 0.8)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 40.hours, :rows => 60,  :size => 600,  :wasted_bytes => 12, :percent_bloat => 0.8)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 39.hours, :rows => 70,  :size => 700,  :wasted_bytes => 14, :percent_bloat => 1.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 38.hours, :rows => 80,  :size => 800,  :wasted_bytes => 16, :percent_bloat => 1.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 37.hours, :rows => 90,  :size => 900,  :wasted_bytes => 18, :percent_bloat => 4.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 36.hours, :rows => 100, :size => 1000, :wasted_bytes => 20, :percent_bloat => 5.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 35.hours, :rows => 110, :size => 1100, :wasted_bytes => 22, :percent_bloat => 6.0)

      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 34.hours, :rows => 120, :size => 1200, :wasted_bytes => 24, :percent_bloat => 9.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 33.hours, :rows => 130, :size => 1300, :wasted_bytes => 26, :percent_bloat => 11.4)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 32.hours, :rows => 130, :size => 1300, :wasted_bytes => 26, :percent_bloat => 11.4)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 31.hours, :rows => 130, :size => 1300, :wasted_bytes => 26, :percent_bloat => 11.4)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 30.hours, :rows => 140, :size => 1400, :wasted_bytes => 28, :percent_bloat => 14.5)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 29.hours, :rows => 150, :size => 1500, :wasted_bytes => 30, :percent_bloat => 15.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 28.hours, :rows => 160, :size => 1600, :wasted_bytes => 32, :percent_bloat => 16.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 27.hours, :rows => 170, :size => 1700, :wasted_bytes => 34, :percent_bloat => 17.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 26.hours, :rows => 180, :size => 1800, :wasted_bytes => 36, :percent_bloat => 18.3)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 25.hours, :rows => 190, :size => 1900, :wasted_bytes => 38, :percent_bloat => 19.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 24.hours, :rows => 200, :size => 2000, :wasted_bytes => 40, :percent_bloat => 20.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 23.hours, :rows => 200, :size => 2000, :wasted_bytes => 40, :percent_bloat => 20.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 22.hours, :rows => 210, :size => 2100, :wasted_bytes => 42, :percent_bloat => 21.6)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 21.hours, :rows => 220, :size => 2200, :wasted_bytes => 44, :percent_bloat => 22.1)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 20.hours, :rows => 240, :size => 2400, :wasted_bytes => 26, :percent_bloat => 24.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 19.hours, :rows => 250, :size => 2500, :wasted_bytes => 28, :percent_bloat => 25.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 18.hours, :rows => 260, :size => 2600, :wasted_bytes => 30, :percent_bloat => 26.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 17.hours, :rows => 290, :size => 2900, :wasted_bytes => 32, :percent_bloat => 29.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 16.hours, :rows => 300, :size => 3000, :wasted_bytes => 34, :percent_bloat => 30.4)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 15.hours, :rows => 340, :size => 3400, :wasted_bytes => 36, :percent_bloat => 34.4)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 14.hours, :rows => 350, :size => 3500, :wasted_bytes => 38, :percent_bloat => 35.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 13.hours, :rows => 350, :size => 3500, :wasted_bytes => 40, :percent_bloat => 35.3)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 12.hours, :rows => 360, :size => 3600, :wasted_bytes => 40, :percent_bloat => 36.5)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 11.hours, :rows => 380, :size => 3800, :wasted_bytes => 42, :percent_bloat => 38.8)

      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 10.hours, :rows => 400, :size => 4000, :wasted_bytes => 44, :percent_bloat => 40.9)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 9.hours, :rows => 410, :size => 4100, :wasted_bytes => 60, :percent_bloat => 41.1)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 8.hours, :rows => 420, :size => 4200, :wasted_bytes => 62, :percent_bloat => 42.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 7.hours, :rows => 420, :size => 4200, :wasted_bytes => 64, :percent_bloat => 42.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 6.hours, :rows => 430, :size => 4300, :wasted_bytes => 70, :percent_bloat => 43.4)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 5.hours, :rows => 440, :size => 4400, :wasted_bytes => 72, :percent_bloat => 44.7)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 4.hours, :rows => 460, :size => 4600, :wasted_bytes => 74, :percent_bloat => 46.3)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 3.hours, :rows => 470, :size => 4700, :wasted_bytes => 76, :percent_bloat => 47.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 2.hours, :rows => 480, :size => 4800, :wasted_bytes => 80, :percent_bloat => 48.5)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts - 1.hour,  :rows => 490, :size => 4900, :wasted_bytes => 84, :percent_bloat => 49.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => index, :timestamp => ts,            :rows => 500, :size => 5000, :wasted_bytes => 90, :percent_bloat => 50.7)
    end

    it "will return 1 row with average daily rollups for metrics" do
      interval_name = 'hourly'
      rollup_date   = Time.gm(2012, 8, 14, 00, 00, 01)
      index.rollup_metrics(interval_name, rollup_date)

      rollup_record = index.vmdb_metrics.where(:capture_interval_name => 'daily').first

      expect(rollup_record).not_to be_nil
      expect(rollup_record.rows).to eq(227)
      expect(rollup_record.size).to eq(2270)
      expect(rollup_record.wasted_bytes).to   be_within(0.01).of(33.83)
      expect(rollup_record.percent_bloat).to  be_within(0.01).of(22.54)
    end

    it "fetches latest metric record" do
      expect(index.latest_hourly_metric.rows).to eq(500)
      expect(index.latest_hourly_metric.size).to eq(5000)
      expect(index.latest_hourly_metric.wasted_bytes).to eq(90)
      expect(index.latest_hourly_metric.percent_bloat).to eq(50.7)
    end
  end
end
