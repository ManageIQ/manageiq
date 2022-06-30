RSpec.describe MiqUiWorker do
  describe ".worker_settings" do
    it "count defaults to 2" do
      EvmSpecHelper.local_miq_server
      expect(described_class.worker_settings[:count]).to eq 2
    end
  end

  context ".all_ports_in_use" do
    let(:zone) { server1.zone }
    let(:server1) { EvmSpecHelper.local_miq_server }
    before do
      require 'util/miq-process'
      allow(MiqProcess).to receive(:is_worker?).and_return(false)

      @worker1 = FactoryBot.create(:miq_ui_worker, :miq_server => server1, :uri => "http://0.0.0.0:3000", :status => 'started')
      @worker2 = FactoryBot.create(:miq_ui_worker, :miq_server => server1, :uri => "http://0.0.0.0:3001", :status => 'started')
    end

    it "normal case" do
      expect(MiqUiWorker.all_ports_in_use.sort).to eq([3000, 3001])
    end

    it "started vs. stopped workers" do
      @worker1.update_attribute(:status, "stopped")
      expect(MiqUiWorker.all_ports_in_use.sort).to eq([3001])
    end

    it "current vs. remote servers" do
      server2 = FactoryBot.create(:miq_server, :zone => zone)
      @worker2.miq_server = server2
      @worker2.save
      expect(MiqUiWorker.all_ports_in_use).to eq([3000])
    end
  end

  describe ".reserve_port" do
    it "returns next free port" do
      ports = (3000..3001).to_a
      expect(described_class.reserve_port(ports)).to eq(3002)
    end

    it "raises if no ports available" do
      ports = (3000..3009).to_a
      expect { described_class.reserve_port(ports) }.to raise_error(NoFreePortError)
    end

    it "returns free port between used ports" do
      ports = [3000, 3002]
      expect(described_class.reserve_port(ports)).to eq(3001)
    end
  end

  it "#preload_for_worker_role autoloads api collection classes and descendants" do
    allow(EvmDatabase).to receive(:seeded_primordially?).and_return(true)
    expect(MiqUiWorker).to receive(:configure_secret_token)
    MiqUiWorker.preload_for_worker_role
    expect(defined?(ServiceAnsibleTower)).to be_truthy
  end
end
