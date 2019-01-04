describe VmdbDatabase do
  context "::MetricCapture" do
    context "#capture_database_metrics" do
      let(:db) { FactoryBot.create(:vmdb_database) }

      context "when database is local" do
        it "populates columns from sql and os sources" do
          pg_disk_usage = [{
            :filesystem          => "/dev/mapper/pg-data",
            :type                => "ext4",
            :total_bytes         => 41149652992,
            :used_bytes          => 9345048576,
            :available_bytes     => 29690675200,
            :used_bytes_percent  => 24,
            :mount_point         => "/",
            :total_inodes        => 2564096,
            :used_inodes         => 188962,
            :available_inodes    => 2375134,
            :used_inodes_percent => 8
          }]

          db.update_attributes(:data_directory => "stubbed")
          expect(EvmDatabase).to receive(:local?).and_return(true)
          expect(MiqSystem).to receive(:disk_usage).and_return(pg_disk_usage)

          db.capture_database_metrics
          metric = db.latest_hourly_metric
          expect(metric).to be_kind_of(VmdbDatabaseMetric)

          (standard_capture_columns + sql_capture_columns + os_capture_columns).each do |column|
            expect(metric.send(column)).not_to be_nil
          end
        end
      end

      context "when database is not local" do
        before do
          allow(EvmDatabase).to receive(:local?).and_return(false)
        end

        it "populates columns from sql sources" do
          db.capture_database_metrics
          metric = db.latest_hourly_metric
          expect(metric).to be_kind_of(VmdbDatabaseMetric)

          (standard_capture_columns + sql_capture_columns).each do |column|
            expect(metric.send(column)).not_to be_nil
          end

          os_capture_columns.each do |column|
            expect(metric.send(column)).to be_nil
          end
        end
      end
    end
  end

  context ".collect_database_metrics_os" do
    it "returns a hash of os sourced columns" do
      actual = VmdbDatabase.collect_database_metrics_os("/")
      expect(actual).to be_kind_of(Hash)
      os_capture_columns.each do |col|
        expect(actual[col.to_sym]).not_to be_nil
      end
    end
  end

  context ".collect_database_metrics_sql" do
    it "returns a hash of sql sourced columns" do
      actual = VmdbDatabase.collect_database_metrics_sql
      expect(actual).to be_kind_of(Hash)
      sql_capture_columns.each do |col|
        expect(actual[col.to_sym]).not_to be_nil
      end
    end
  end

  def standard_capture_columns
    %w( timestamp capture_interval_name )
  end

  def sql_capture_columns
    %w( active_connections )
  end

  def os_capture_columns
    %w(
      running_processes
      disk_total_bytes
      disk_used_bytes
      disk_free_bytes
      disk_total_inodes
      disk_used_inodes
      disk_free_inodes
    )
  end
end
