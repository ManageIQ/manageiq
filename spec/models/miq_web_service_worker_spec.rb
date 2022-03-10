RSpec.describe MiqWebServiceWorker do
  describe ".worker_settings" do
    it "count defaults to 2" do
      EvmSpecHelper.local_miq_server
      expect(described_class.worker_settings[:count]).to eq 2
    end
  end

  it "preload_for_worker_role autoloads api collection classes and descendants" do
    allow(EvmDatabase).to receive(:seeded_primordially?).and_return(true)
    expect(MiqWebServiceWorker).to receive(:configure_secret_token)
    MiqWebServiceWorker.preload_for_worker_role
    expect(defined?(ServiceAnsibleTower)).to be_truthy
  end
end
