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

  describe "#start_servers" do
    context "when podified" do
      before do
        allow(MiqEnvironment::Command).to receive(:is_podified?).and_return(true)
      end

      it "impersonates and starts just created servers in region" do
        subject
        2.times { FactoryBot.create(:miq_server_in_default_zone) }
        expect(subject).to receive(:impersonate_server).twice
        expect(subject).to receive(:start_server).twice
        subject.start_servers
      end

      it "impersonates and starts previously created servers in region" do
        2.times { FactoryBot.create(:miq_server_in_default_zone) }
        expect(subject).to receive(:impersonate_server).twice
        expect(subject).to receive(:start_server).twice
        subject.start_servers
      end
    end

    context "when appliances" do
      it "impersonates and starts just created my_server" do
        subject
        EvmSpecHelper.local_miq_server
        2.times { FactoryBot.create(:miq_server_in_default_zone) }
        expect(subject).to receive(:impersonate_server).once
        expect(subject).to receive(:start_server).once
        subject.start_servers
      end

      it "impersonates and starts previously created my_server" do
        EvmSpecHelper.local_miq_server
        2.times { FactoryBot.create(:miq_server_in_default_zone) }

        expect(subject).to receive(:impersonate_server).once
        expect(subject).to receive(:start_server).once
        subject.start_servers
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
        allow(Vmdb::Settings::Validator).to receive(:new).and_return(double(:valid? => true, :validate => [true, {}]))
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
        subject.send(:as_each_server) { received_ids << Settings.special.settings[:id] }
        expect(received_ids).to match_array(MiqServer.pluck(:id))
      end
    end
  end

  let(:hostname) { "ABCDEFG" }
  let(:address) { "AB:CD:EF:GH" }
  let(:vm1_network) { FactoryBot.create(:network, :hostname => hostname) }
  let(:vm2_network) { FactoryBot.create(:network) }
  let(:vm3_device) { FactoryBot.create(:guest_device, :address => address, :device_type => "ethernet") }
  let(:vm1) { FactoryBot.create(:vm_vmware, :hardware => FactoryBot.create(:hardware, :networks => [vm1_network])) }
  let(:vm2) { FactoryBot.create(:vm_vmware, :hardware => FactoryBot.create(:hardware, :networks => [vm2_network])) }
  let(:vm3) { FactoryBot.create(:vm_vmware, :hardware => FactoryBot.create(:hardware, :guest_devices => [vm3_device])) }

  describe "#set_local_vserver_vm (private)" do
    let!(:miq_server) { EvmSpecHelper.local_miq_server }
    let(:evm_server) { EvmServer.new }

    # Basically stock, just ensure podified environment doesn't modify this test.
    before { allow(evm_server).to receive(:servers_from_db).and_return([miq_server]) }

    it "handles no matching servers" do
      vm1
      vm2

      # sets evm_server.current_server
      evm_server.send(:impersonate_server, miq_server)
      evm_server.send(:set_local_server_vm)
      expect(miq_server.reload.vm_id).to eq(nil)
    end

    it "finds local server (by mac_address)" do
      vm1
      vm2
      miq_server.update(:hostname => vm1_network.hostname)

      evm_server.send(:impersonate_server, miq_server)
      evm_server.send(:set_local_server_vm)
      expect(miq_server.reload.vm_id).to eq(vm1.id)
    end

    it "finds multiple servers" do
      vm1
      vm2
      vm3

      miq_server.update(:hostname => vm1_network.hostname, :ipaddress => vm2_network.ipaddress)

      evm_server.send(:impersonate_server, miq_server)
      evm_server.send(:set_local_server_vm)
      expect(miq_server.reload.vm_id).to eq(nil)
    end
  end

  context "#find_vms_by_mac_address_and_hostname_and_ipaddress (private)" do
    subject { described_class.new }

    it "mac_address" do
      vm1
      vm2
      vm3
      subject

      expect do
        expect(subject.send(:find_vms_by_mac_address_and_hostname_and_ipaddress, address, nil, nil)).to eq([vm3])
      end.to make_database_queries(:count => 1)
    end

    it "hostname" do
      vm1
      vm2
      subject

      expect do
        expect(subject.send(:find_vms_by_mac_address_and_hostname_and_ipaddress, nil, hostname, nil)).to eq([vm1])
      end.to make_database_queries(:count => 1)
    end

    it "ipaddress" do
      vm1
      vm2
      subject

      expect do
        expect(subject.send(:find_vms_by_mac_address_and_hostname_and_ipaddress, nil, nil, vm1_network.ipaddress)).to eq([vm1])
      end.to make_database_queries(:count => 1)
    end

    it "hostname and ipaddress" do
      vm1
      vm2
      subject

      expect do
        expect(subject.send(:find_vms_by_mac_address_and_hostname_and_ipaddress, nil, vm1_network.hostname, vm1_network.ipaddress)).to eq([vm1])
      end.to make_database_queries(:count => 1)
    end

    it "hostname and different ipaddress" do
      vm1
      vm2
      subject

      expect do
        expect(subject.send(:find_vms_by_mac_address_and_hostname_and_ipaddress, nil, vm1_network.hostname, vm2_network.ipaddress)).to be_empty
      end.to make_database_queries(:count => 1)
    end

    # vm must match both mac address and a hostname from a single server
    # not sure if that was the original intent, but how the code currently works
    it "mac address and different hostname" do
      vm1
      vm3
      subject

      expect do
        expect(subject.send(:find_vms_by_mac_address_and_hostname_and_ipaddress, address, vm1_network.hostname, nil)).to be_empty
      end.to make_database_queries(:count => 1)
    end

    it "returns an empty list when all are blank" do
      vm1
      subject

      expect do
        expect(subject.send(:find_vms_by_mac_address_and_hostname_and_ipaddress, nil, nil, nil)).to eq([])
        expect(subject.send(:find_vms_by_mac_address_and_hostname_and_ipaddress, '', '', '')).to eq([])
      end.not_to make_database_queries
    end
  end
end
