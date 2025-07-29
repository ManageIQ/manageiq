describe ManageIQ::Session::ActiveRecordStoreAdapter do
  describe "#enable_rack_session_debug_logger" do
    let(:adapter) { described_class.new }

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
