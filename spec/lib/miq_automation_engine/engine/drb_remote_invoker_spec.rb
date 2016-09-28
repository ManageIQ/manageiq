module DrbRemoteInvokerSpec
  include MiqAeEngine
  describe MiqAeEngine::DrbRemoteInvoker do
    it "setup/teardown drb_for_ruby_method clears DRb threads" do
      workspace = double("workspace", :persist_state_hash => {})
      allow(workspace).to receive(:disable_rbac).with(no_args)
      invoker = described_class.new(workspace)

      timer_thread = nil

      invoker.with_server([], "") do
        timer_thread = Thread.list.each do |t|
          first = t.backtrace_locations.first
          if first && first.path.include?("timeridconv.rb")
            timer_thread = t
            break
          end
        end
      end

      expect(Thread.list).to_not include(timer_thread)
    end
  end
end
