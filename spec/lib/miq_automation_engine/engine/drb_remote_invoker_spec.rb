module DrbRemoteInvokerSpec
  include MiqAeEngine
  describe MiqAeEngine::DrbRemoteInvoker do
    it "setup/teardown drb_for_ruby_method clears DRb threads" do
      threads_before = Thread.list.select(&:alive?)

      invoker = described_class.new(nil)

      invoker.setup
      expect(Thread.list.select(&:alive?) - threads_before).not_to be_empty

      invoker.teardown
      expect(Thread.list.select(&:alive?)).to eq threads_before
    end
  end
end
