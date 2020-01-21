describe VmdbTable do
  context "#latest_hourly_metric" do
    let(:db)    { FactoryBot.create(:vmdb_database) }
    let(:table) { FactoryBot.create(:vmdb_table, :vmdb_database => db, :name => 'foo') }

    it "fetches latest metric record" do
      ts = Time.gm(2012, 8, 15, 10, 00, 01)         # Need specific date in order to keep track of rollup data...

      FactoryBot.create(:vmdb_metric_hourly, :resource => table, :timestamp => ts - 10.hours, :rows => 400, :size => 4000, :wasted_bytes => 44, :percent_bloat => 40.9)
      FactoryBot.create(:vmdb_metric_hourly, :resource => table, :timestamp => ts - 9.hours,  :rows => 410, :size => 4100, :wasted_bytes => 60, :percent_bloat => 41.1)
      FactoryBot.create(:vmdb_metric_hourly, :resource => table, :timestamp => ts - 8.hours,  :rows => 420, :size => 4200, :wasted_bytes => 62, :percent_bloat => 42.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => table, :timestamp => ts - 7.hours,  :rows => 420, :size => 4200, :wasted_bytes => 64, :percent_bloat => 42.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => table, :timestamp => ts - 6.hours,  :rows => 430, :size => 4300, :wasted_bytes => 70, :percent_bloat => 43.4)
      FactoryBot.create(:vmdb_metric_hourly, :resource => table, :timestamp => ts - 5.hours,  :rows => 440, :size => 4400, :wasted_bytes => 72, :percent_bloat => 44.7)
      FactoryBot.create(:vmdb_metric_hourly, :resource => table, :timestamp => ts - 4.hours,  :rows => 460, :size => 4600, :wasted_bytes => 74, :percent_bloat => 46.3)
      FactoryBot.create(:vmdb_metric_hourly, :resource => table, :timestamp => ts - 3.hours,  :rows => 470, :size => 4700, :wasted_bytes => 76, :percent_bloat => 47.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => table, :timestamp => ts - 2.hours,  :rows => 480, :size => 4800, :wasted_bytes => 80, :percent_bloat => 48.5)
      FactoryBot.create(:vmdb_metric_hourly, :resource => table, :timestamp => ts - 1.hour,   :rows => 490, :size => 4900, :wasted_bytes => 84, :percent_bloat => 49.0)
      FactoryBot.create(:vmdb_metric_hourly, :resource => table, :timestamp => ts,            :rows => 500, :size => 5000, :wasted_bytes => 90, :percent_bloat => 50.7)

      expect(table.latest_hourly_metric.rows).to eq(500)
      expect(table.latest_hourly_metric.size).to eq(5000)
      expect(table.latest_hourly_metric.wasted_bytes).to eq(90)
      expect(table.latest_hourly_metric.percent_bloat).to eq(50.7)
    end
  end
end
