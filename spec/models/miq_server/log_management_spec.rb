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

describe MiqServer do
  context "LogManagement" do
    let(:server_depot) { FactoryGirl.create(:file_depot) }
    let(:zone_depot) { FactoryGirl.create(:file_depot) }
    let(:miq_task) { FactoryGirl.create(:miq_task) }

    before do
      _, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
      @miq_server2          = FactoryGirl.create(:miq_server, :zone => @zone)
    end

    context "#pg_data_log_patterns" do
      it "nil pg_data_dir" do
        allow(@miq_server).to receive_messages(:pg_data_dir => nil)
        expect(@miq_server.pg_log_patterns).to eql []
      end

      it "pg_data_dir set" do
        allow(@miq_server).to receive_messages(:pg_data_dir => '/var/lib/pgsql/data')
        expected = %w(/var/lib/pgsql/data/*.conf /var/lib/pgsql/data/pg_log/*)
        expect(@miq_server.pg_log_patterns.collect(&:to_s)).to match_array expected
      end
    end

    it "#current_log_patterns" do
      allow(@miq_server).to receive_messages(:current_log_pattern_configuration => %w(/var/log/syslog*))
      allow(@miq_server).to receive_messages(:pg_log_patterns => %w(/var/lib/pgsql/data/*.conf))
      expect(@miq_server.current_log_patterns).to match_array %w(/var/log/syslog* /var/lib/pgsql/data/*.conf)
    end

    it "#current_log_patterns with pg_logs duplicated in current_log_pattern_configuration" do
      allow(@miq_server).to receive_messages(:current_log_pattern_configuration => %w(/var/log/syslog* /var/lib/pgsql/data/*.conf))
      allow(@miq_server).to receive_messages(:pg_log_patterns => %w(/var/lib/pgsql/data/*.conf))
      expect(@miq_server.current_log_patterns).to match_array %w(/var/log/syslog* /var/lib/pgsql/data/*.conf)
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
