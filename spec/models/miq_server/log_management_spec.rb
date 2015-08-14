require "spec_helper"

describe MiqServer do
  context "LogManagement" do
    before do
      _, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
      @miq_server2          = FactoryGirl.create(:miq_server, :zone => @zone)
    end

    context "#pg_data_log_patterns" do
      it "nil pg_data_dir" do
        @miq_server.stub(:pg_data_dir => nil)
        expect(@miq_server.pg_log_patterns).to eql []
      end

      it "pg_data_dir set" do
        @miq_server.stub(:pg_data_dir => '/var/lib/pgsql/data')
        expected = %w(/var/lib/pgsql/data/*.conf /var/lib/pgsql/data/pg_log/*)
        expect(@miq_server.pg_log_patterns.collect(&:to_s)).to match_array expected
      end
    end

    it "#current_log_patterns" do
      @miq_server.stub(:current_log_pattern_configuration => %w(/var/log/syslog*))
      @miq_server.stub(:pg_log_patterns => %w(/var/lib/pgsql/data/*.conf))
      expect(@miq_server.current_log_patterns).to match_array %w(/var/log/syslog* /var/lib/pgsql/data/*.conf)
    end

    it "#current_log_patterns with pg_logs duplicated in current_log_pattern_configuration" do
      @miq_server.stub(:current_log_pattern_configuration => %w(/var/log/syslog* /var/lib/pgsql/data/*.conf))
      @miq_server.stub(:pg_log_patterns => %w(/var/lib/pgsql/data/*.conf))
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

    context "#log_depot" do
      it "server log_file_depot configured" do
        server_depot = FactoryGirl.create(:file_depot)
        @miq_server.log_file_depot = server_depot

        @miq_server.log_depot.should == server_depot
      end

      it "zone log_file_depot configured" do
        zone_depot = FactoryGirl.create(:file_depot)
        @zone.log_file_depot = zone_depot

        @miq_server.log_depot.should == zone_depot
      end

      it "server and zone log_file_depot configured" do
        server_depot = FactoryGirl.create(:file_depot)
        zone_depot   = FactoryGirl.create(:file_depot)
        @miq_server.log_file_depot = server_depot
        @zone.log_file_depot = zone_depot

        @miq_server.log_depot.should == server_depot
      end
    end
  end
end
