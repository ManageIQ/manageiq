describe ManageIQ::Session::MemCacheStoreAdapter do
  describe "#enable_rack_session_debug_logger" do
    let(:adapter) { described_class.new }

    it "returns nil in production environment" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      expect(adapter).to receive(:rack_session_class_to_prepend).never
      expect(adapter.enable_rack_session_debug_logger).to be_nil
    end

    context "in non-production environment" do
      let(:mock_class) { Class.new }

      it "enables debug logging and returns a truthy value" do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
        allow(adapter).to receive(:rack_session_class_to_prepend).and_return(mock_class)

        expect(mock_class).to receive(:prepend).and_call_original
        expect(adapter).to receive(:puts).with(/enabling/i)
        expect(adapter.enable_rack_session_debug_logger).to be_truthy
      end
    end
  end
end
