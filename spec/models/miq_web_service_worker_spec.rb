RSpec.describe MiqWebServiceWorker do
  it "preload_for_worker_role autoloads api collection classes and descendants" do
    allow(EvmDatabase).to receive(:seeded_primordially?).and_return(true)
    expect(MiqWebServiceWorker).to receive(:configure_secret_token)
    MiqWebServiceWorker.preload_for_worker_role
    expect(defined?(ServiceAnsibleTower)).to be_truthy
  end
end
