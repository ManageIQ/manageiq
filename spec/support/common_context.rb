RSpec.shared_context 'with local server', :with_local_miq_server do
  before do
    MiqRegion.seed

    @zone = EvmSpecHelper.local_miq_server.zone
  end
end
