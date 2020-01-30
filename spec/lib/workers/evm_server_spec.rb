require "workers/evm_server"

describe EvmServer do
  describe ".new" do
    it "sets the servers_to_monitor to the current server" do
      server = EvmSpecHelper.local_miq_server
      servers_to_monitor = subject.servers_to_monitor

      expect(servers_to_monitor.count).to eq(1)
      expect(servers_to_monitor.first.id).to eq(server.id)
    end

    it "doesn't give a nil server when there is no local server" do
      expect(subject.servers_to_monitor).to be_empty
    end

    context "when podified" do
      let(:expected_ids) { MiqServer.pluck(:id) }

      before do
        4.times { FactoryBot.create(:miq_server) }
        allow(MiqEnvironment::Command).to receive(:is_podified?).and_return(true)
      end

      it "sets the servers_to_monitor to all servers" do
        received_ids = subject.servers_to_monitor.map(&:id)

        expect(received_ids).to match_array(expected_ids)
      end
    end
  end

  describe "#refresh_servers_to_monitor" do
    it "doesn't change anything when not podified" do
      server = EvmSpecHelper.local_miq_server
      servers_to_monitor = subject.servers_to_monitor
      expect(servers_to_monitor.first.id).to eq(server.id)

      4.times { FactoryBot.create(:miq_server) }
      subject.refresh_servers_to_monitor

      servers_to_monitor = subject.servers_to_monitor
      expect(servers_to_monitor.count).to eq(1)
      expect(servers_to_monitor.first.id).to eq(server.id)
    end

    context "when podified" do
      before do
        FactoryBot.create(:miq_server)
        allow(MiqEnvironment::Command).to receive(:is_podified?).and_return(true)
      end

      it "sets the servers_to_monitor to all servers" do
        expect(subject.servers_to_monitor.count).to eq(1)
        expect(subject.servers_to_monitor.first.id).to eq(MiqServer.first.id)

        4.times { FactoryBot.create(:miq_server) }

        num_servers = MiqServer.count

        # one for each new server
        expect(subject).to receive(:impersonate_server).exactly(num_servers - 1).times
        expect(subject).to receive(:start_server).exactly(num_servers - 1).times
        subject.refresh_servers_to_monitor

        expect(subject.servers_to_monitor.count).to eq(num_servers)
        expect(subject.servers_to_monitor.map(&:id)).to match_array(MiqServer.all.map(&:id))
      end

      it "removes a server when it is removed from the database" do
        server = FactoryBot.create(:miq_server)
        expect(subject.servers_to_monitor.map(&:id)).to include(server.id)

        monitor_server = subject.servers_to_monitor.find { |s| s.id == server.id }
        expect(monitor_server).to receive(:shutdown)

        server.delete
        subject.refresh_servers_to_monitor

        expect(subject.servers_to_monitor.map(&:id)).not_to include(server.id)
      end

      # Note: this is a very important spec
      # A lot of the data about the current server is stored as instance variables
      # so losing the particular instance we're using to do worker management would
      # be a big problem
      it "doesn't change the existing server instances" do
        initial_object_id = subject.servers_to_monitor.first.object_id

        4.times { FactoryBot.create(:miq_server) }
        allow(subject).to receive(:impersonate_server)
        allow(subject).to receive(:start_server)
        subject.refresh_servers_to_monitor

        new_objects = subject.servers_to_monitor.map(&:object_id)
        expect(new_objects).to include(initial_object_id)

        subject.refresh_servers_to_monitor

        expect(subject.servers_to_monitor.map(&:object_id)).to match_array(new_objects)
      end
    end
  end

  describe "#as_each_server (private)" do
    it "yields the local server when not podified" do
      server = EvmSpecHelper.local_miq_server
      subject.send(:as_each_server) do
        expect(MiqServer.my_server.guid).to eq(server.guid)
        expect(subject.instance_variable_get(:@current_server).guid).to eq(server.guid)
      end
    end

    context "when podified" do
      let(:expected_guids) { MiqServer.pluck(:guid) }

      before do
        4.times { FactoryBot.create(:miq_server) }
        allow(MiqEnvironment::Command).to receive(:is_podified?).and_return(true)
      end

      it "sets the server variable to each server" do
        received_guids = []
        subject.send(:as_each_server) { received_guids << subject.instance_variable_get(:@current_server).guid }

        expect(received_guids).to match_array(expected_guids)
      end

      it "sets my_server to each server" do
        received_guids = []
        subject.send(:as_each_server) { received_guids << MiqServer.my_server.guid }

        expect(received_guids).to match_array(expected_guids)
      end

      it "resets ::Settings to the correct server" do
        MiqServer.all.each do |server|
          server.add_settings_for_resource(:special => {:settings => {:id => server.id}})
        end

        received_ids = []
        subject.send(:as_each_server) { received_ids << ::Settings.special.settings[:id] }
        expect(received_ids).to match_array(MiqServer.pluck(:id))
      end
    end
  end
end
