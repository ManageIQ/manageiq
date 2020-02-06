def stub_vmdb_util_methods_for_collection_log
  allow(VMDB::Util).to receive(:zip_logs)
  allow(VMDB::Util).to receive(:compressed_log_patterns).and_return(["log/evm.1122.gz"])
  allow(VMDB::Util).to receive(:get_evm_log_for_date).and_return("20151209_141429_20151217_140845")
  allow(VMDB::Util).to receive(:get_log_start_end_times).and_return([Time.zone.now, Time.zone.now])
end

shared_examples "post_[type_of_log]_logs" do |type, type_of_log|
  it "uses #{type} file_depot in LogFile for upload" do
    @zone.log_file_depot = zone_depot
    @miq_server.log_file_depot = server_depot

    stub_vmdb_util_methods_for_collection_log
    allow_any_instance_of(LogFile).to receive(:upload)
    allow_any_instance_of(MiqServer).to receive(:current_log_patterns)

    method = "post_#{type_of_log}_logs".to_sym
    @miq_server.send(method, miq_task.id, @miq_server.log_depot(type))
    log_file_depot = LogFile.first.file_depot

    if type == "Zone"
      expect(log_file_depot).to eq(zone_depot)
      expect(log_file_depot).not_to eq(server_depot)
    else
      expect(log_file_depot).not_to eq(zone_depot)
      expect(log_file_depot).to eq(server_depot)
    end

    expect(LogFile.first.miq_task).to eq(miq_task)
  end
end

shared_examples "post_logs_uses_depot" do |is_zone_depot, is_server_depot, context|
  it "uses #{context} depot" do
    if is_zone_depot
      @zone.log_file_depot = zone_depot
    end

    if is_server_depot
      @miq_server.log_file_depot = server_depot
    end

    stub_vmdb_util_methods_for_collection_log
    allow_any_instance_of(LogFile).to receive(:upload)
    allow_any_instance_of(MiqServer).to receive(:current_log_patterns)

    @miq_server.post_logs(:taskid => miq_task.id, :context => context)

    log_file_depot = LogFile.first.file_depot

    if context == "Zone"
      expect(log_file_depot).to eq(zone_depot)
    else
      expect(log_file_depot).to eq(server_depot)
    end
  end
end

shared_examples "post_logs_fails" do |is_zone_depot, is_server_depot, context|
  it "raises error 'Log depot settings not configured'" do
    if is_zone_depot
      @zone.log_file_depot = zone_depot
    end

    if is_server_depot
      @miq_server.log_file_depot = server_depot
    end

    stub_vmdb_util_methods_for_collection_log
    allow_any_instance_of(LogFile).to receive(:upload)
    allow_any_instance_of(MiqServer).to receive(:current_log_patterns)

    expect do
      @miq_server.post_logs(:taskid => miq_task.id, :context => context)
    end.to raise_error(RuntimeError, "Log depot settings not configured")
  end
end

RSpec.describe MiqServer do
  context "LogManagement" do
    let(:server_depot) { FactoryBot.create(:file_depot) }
    let(:zone_depot) { FactoryBot.create(:file_depot) }
    let(:miq_task) { FactoryBot.create(:miq_task) }

    before do
      _, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
      @miq_server2          = FactoryBot.create(:miq_server, :zone => @zone)
    end

    context "#pg_data_log_patterns" do
      it "nil pg_data_dir" do
        allow(@miq_server).to receive_messages(:pg_data_dir => nil)
        expect(@miq_server.pg_log_patterns).to eql []
      end

      it "pg_data_dir set" do
        allow(@miq_server).to receive_messages(:pg_data_dir => '/var/lib/pgsql/data')
        expected = %w(/var/lib/pgsql/data/*.conf /var/lib/pgsql/data/pg_log/* /etc/manageiq/postgresql.conf.d/*)
        expect(@miq_server.pg_log_patterns.collect(&:to_s)).to match_array expected
      end
    end

    it "#current_log_patterns" do
      stub_settings(:log => {:collection => {:current => {:pattern => %w(/var/log/syslog*)}}})
      allow(@miq_server).to receive_messages(:pg_log_patterns => %w(/var/lib/pgsql/data/*.conf))
      expect(@miq_server.current_log_patterns).to match_array %w(/var/log/syslog* /var/lib/pgsql/data/*.conf)
    end

    it "#current_log_patterns with pg_logs duplicated in current_log_pattern_configuration" do
      stub_settings(
        :log => {:collection => {:current => {:pattern => %w(/var/log/syslog* /var/lib/pgsql/data/*.conf)}}})
      allow(@miq_server).to receive_messages(:pg_log_patterns => %w(/var/lib/pgsql/data/*.conf))
      expect(@miq_server.current_log_patterns).to match_array %w(/var/log/syslog* /var/lib/pgsql/data/*.conf)
    end

    context "post current/historical/models/dialogs" do
      let(:task)                      { FactoryBot.create(:miq_task) }
      let(:compressed_log_patterns)   { [Rails.root.join("log", "evm*.log.gz").to_s] }
      let(:current_log_patterns)      { [Rails.root.join("log", "evm.log").to_s] }
      let(:compressed_evm_log)        { Rails.root.join("evm.log-20180319.gz").to_s }
      let(:log_start)                 { Time.zone.parse("2018-05-11 11:33:12 UTC") }
      let(:log_end)                   { Time.zone.parse("2018-05-11 15:34:16 UTC") }
      let(:daily_log)                 { Rails.root.join("data", "user", "system", "evm_server_daily.zip").to_s }
      let(:log_depot)                 { FactoryBot.create(:file_depot) }
      let!(:region)                   { MiqRegion.seed }
      let(:zone)                      { @miq_server.zone }
      before do
        require 'vmdb/util'
        allow(VMDB::Util).to receive(:compressed_log_patterns).and_return(compressed_log_patterns)
        allow(VMDB::Util).to receive(:get_evm_log_for_date).and_return(compressed_evm_log)
        allow(VMDB::Util).to receive(:get_log_start_end_times).and_return([log_start, log_end])
        allow(VMDB::Util).to receive(:zip_logs).and_return(daily_log)
        allow(@miq_server).to receive(:current_log_patterns).and_return(current_log_patterns)
        allow(@miq_server).to receive(:backup_automate_dialogs)
        allow(@miq_server).to receive(:backup_automate_models)
        %w(historical_logfile current_logfile).each do |kind|
          logfile = FactoryBot.create(:log_file, :historical => kind == "historical_logfile")
          allow(logfile).to receive(:upload)
          allow(LogFile).to receive(kind).and_return(logfile)
        end
      end

      %w(
        Archive post_historical_logs
        Current post_current_logs
        Models post_automate_models
        Dialogs post_automate_dialogs
      ).each_slice(2) do |name, method|
        it "##{method}" do
          logfile = nil

          now = Time.zone.now
          Timecop.freeze(now) do
            @miq_server.send(method, task.id, log_depot)
            logfile = @miq_server.reload.log_files.first
          end

          if %w[Current Archive].include?(name)
            expected_name = [name, "region", region.region, zone.name, zone.id, @miq_server.name, @miq_server.id, "20180511_113312 20180511_153416"].join(" ")
            expect(logfile).to have_attributes(
              :file_depot         => log_depot,
              :local_file         => daily_log,
              :logging_started_on => log_start,
              :logging_ended_on   => log_end,
              :name               => expected_name,
              :description        => "Logs for Zone #{@miq_server.zone.name} Server #{@miq_server.name} 20180511_113312 20180511_153416",
              :miq_task_id        => task.id
            )
            expected_filename = "#{name}_region_#{region.region}_#{zone.name}_#{zone.id}_#{@miq_server.name}_#{@miq_server.id}_20180511_113312_20180511_153416.zip"
            expected_filename.gsub!(/\s+/, "_")
            expect(logfile.destination_file_name).to eq(expected_filename)
          else
            formatted_now = now.strftime("%Y%m%d_%H%M%S")
            expected_name = [name, "region", region.region, zone.name, zone.id, @miq_server.name, @miq_server.id, formatted_now, formatted_now].join(" ")
            expect(logfile).to have_attributes(
              :file_depot         => log_depot,
              :local_file         => daily_log,
              :logging_started_on => be_within(1).of(now),
              :logging_ended_on   => be_within(1).of(now),
              :name               => expected_name,
              :description        => "Logs for Zone #{@miq_server.zone.name} Server #{@miq_server.name} #{formatted_now} #{formatted_now}",
              :miq_task_id        => task.id
            )
          end
          expect(task.reload).to have_attributes(
            :message => "#{name} log files from #{@miq_server.name} #{@miq_server.zone.name} MiqServer #{@miq_server.id} are posted",
            :state   => "Active",
            :status  => "Ok",
          )
        end
      end
    end

    context "#synchronize_logs" do
      it "passes along server override" do
        @miq_server.synchronize_logs("system", @miq_server2)
        expect(MiqTask.first.miq_server_id).to eql @miq_server2.id
        expect(MiqQueue.first.args.first[:id]).to eql @miq_server2.id
      end

      it "passes 'self' server if no server arg" do
        @miq_server2.synchronize_logs("system")
        expect(MiqTask.first.miq_server_id).to eql @miq_server2.id
        expect(MiqQueue.first.args.first[:id]).to eql @miq_server2.id
      end
    end

    describe "#log_depot" do
      it "server log_file_depot configured" do
        @miq_server.log_file_depot = server_depot
        expect(@miq_server.log_depot("MiqServer")).to eq(server_depot)
      end

      it "zone log_file_depot configured" do
        @zone.log_file_depot = zone_depot
        expect(@miq_server.log_depot("Zone")).to eq(zone_depot)
      end

      it "server and zone log_file_depot configured" do
        @miq_server.log_file_depot = server_depot
        @zone.log_file_depot = zone_depot
        expect(@miq_server.log_depot("Zone")).to eq(zone_depot)
        expect(@miq_server.log_depot("MiqServer")).to eq(server_depot)
      end
    end

    describe "#post_historical_logs" do
      context "Server" do
        include_examples "post_[type_of_log]_logs", "MiqServer", :historical
      end

      context "Zone" do
        include_examples "post_[type_of_log]_logs", "Zone", :historical
      end
    end

    describe "#post_current_logs" do
      context "Server" do
        include_examples "post_[type_of_log]_logs", "MiqServer", :current
      end

      context "Zone" do
        include_examples "post_[type_of_log]_logs", "Zone", :current
      end
    end

    describe "#post_logs" do
      context "Zone collection log requested, Zone depot is defined, MiqServer is defined" do
        include_examples "post_logs_uses_depot", true, true, "Zone"
      end

      context "Zone collection log requested, Zone depot is defined, MiqServer is not defined" do
        include_examples "post_logs_uses_depot", true, false, "Zone"
      end

      context "Zone collection log requested, zone depot is not defined, MiqServer defined" do
        include_examples "post_logs_fails", false, true, "Zone"
      end

      context "Zone collection log requested, zone depot is not defined, MiqServer is not defined" do
        include_examples "post_logs_fails", false, false, "Zone"
      end

      context "MiqServer collection log requested, Zone depot is defined, MiqServer is defined" do
        include_examples "post_logs_uses_depot", true, true, "MiqServer"
      end

      context "MiqServer collection log requested, Zone depot is defined, MiqServer is not defined" do
        include_examples "post_logs_fails", true, false, "MiqServer"
      end

      context "MiqServer collection log requested, zone depot is not defined, server defined" do
        include_examples "post_logs_uses_depot", false, true, "MiqServer"
      end

      context "MiqServer collection log requested, zone depot is not defined, MiqServer is not defined" do
        include_examples "post_logs_fails", false, false, "MiqServer"
      end
    end
  end
end
