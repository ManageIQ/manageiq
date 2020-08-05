require 'socket'

RSpec.describe "Server Environment Management" do
  let(:mac_address) { 'a:1:b:2:c:3:d:4' }
  let(:hostname) { Socket.gethostname }
  let(:loopback) { '127.0.0.1' }

  context ".get_network_information" do
    it "when in non-production mode" do
      require "uuidtools"
      allow(UUIDTools::UUID).to receive(:mac_address).and_return(mac_address)
      expect(MiqServer.get_network_information).to eq([loopback, hostname, mac_address])
    end
  end

  context "#check_disk_usage" do
    before do
      _, @miq_server, = EvmSpecHelper.create_guid_miq_server_zone
      allow(@miq_server).to receive_messages(:disk_usage_threshold => 70)
    end

    it "normal usage" do
      expect(@miq_server.check_disk_usage([:used_bytes_percent => 50]))
      expect(MiqQueue.count).to eql 0
    end

    [
      '/var/lib/pgsql',        'evm_server_db_disk_high_usage',
      '/var/www/miq/vmdb/log', 'evm_server_log_disk_high_usage',
      '/',                     'evm_server_system_disk_high_usage',
      '/boot',                 'evm_server_boot_disk_high_usage',
      '/home',                 'evm_server_home_disk_high_usage',
      '/var',                  'evm_server_var_disk_high_usage',
      '/var/log',              'evm_server_var_log_disk_high_usage',
      '/var/log/audit',        'evm_server_var_log_audit_disk_high_usage',
      '/var/www/miq/vmdb/log', 'evm_server_log_disk_high_usage',
      '/var/www/miq_tmp',      'evm_server_miq_tmp_disk_high_usage',
      '/tmp',                  'evm_server_tmp_disk_high_usage'
    ].each_slice(2) do |path, event|
      it "raises an event when disk exceeds usage for #{path}" do
        disks = [{:used_bytes_percent => 85, :mount_point => path}]
        expect(@miq_server.check_disk_usage(disks))
        expect(MiqQueue.count).to eql(1)
        queue = MiqQueue.first

        expect(queue.method_name).to eql("raise_evm_event")
        expect(queue.args[1]).to eql(event)
        expect(queue.args[2][:event_details]).to include disks.first[:mount_point]
      end
    end
  end
end
