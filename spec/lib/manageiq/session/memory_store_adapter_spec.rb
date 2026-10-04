describe ManageIQ::Session::MemoryStoreAdapter do
  let(:adapter) { described_class.new }

  describe "#type" do
    it "returns :memory_store" do
      expect(adapter.type).to eq(:memory_store)
    end
  end

  describe "#enable_rack_session_debug_logger" do
    it "returns nil in production environment" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      expect(adapter.enable_rack_session_debug_logger).to be_nil
    end

    it "returns nil (inherited behavior from AbstractStoreAdapter) in non-production environment" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      expect(adapter.enable_rack_session_debug_logger).to be_nil
    end
  end
end
