$LOAD_PATH << Rails.root.join("tools").to_s

require "server_settings_replicator/server_settings_replicator"

RSpec.describe ServerSettingsReplicator do
  let(:miq_server) { EvmSpecHelper.local_miq_server }
  let!(:miq_server_remote) { EvmSpecHelper.remote_miq_server }
  let(:settings) { {:k1 => {:k2 => {:k3 => 'v3'}}} }

  describe "#replicate" do
    it "targets only other servers" do
      miq_server.add_settings_for_resource(settings)
      expected_output = <<~MESSAGE
        Replicating from server id=#{miq_server.id}, path=k1/k2 to 1 servers
        Settings: {:k1=>{:k2=>{:k3=>"v3"}}}
        Done
      MESSAGE
      expect(described_class).to receive(:copy_to).with([miq_server_remote], settings)
      expect { described_class.replicate(miq_server, 'k1/k2') }.to output(expected_output).to_stdout
    end
  end

  describe "#construct_setting_tree" do
    it "handle simple value" do
      path = [:k1, :k2]
      values = 'abc'
      expect(described_class.construct_setting_tree(path, values)).to eq(:k1 => {:k2 => 'abc'})
    end

    it "handle hash value" do
      path = [:k1, :k2]
      values = {:k3 => 'v3', :k4 => 'v4'}
      expect(described_class.construct_setting_tree(path, values)).to eq(:k1 => {:k2 => {:k3 => 'v3', :k4 => 'v4'}})
    end
  end
end
