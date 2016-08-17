require 'spec_helper'
module DrbRemoteInvokerSpec
  include MiqAeEngine
  describe MiqAeEngine::DrbRemoteInvoker do
    let(:user) { FactoryGirl.create(:user_with_group) }
    it "setup/teardown drb_for_ruby_method clears DRb threads" do
      workspace = double("workspace", :persist_state_hash => {}, :ae_user => user)
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

  describe MiqAeEngine::DrbRemoteInvoker do
    include Spec::Support::AutomationHelper
    context "#api_token" do
      let(:user) { FactoryGirl.create(:user_with_group) }

      def token_script
        <<-'RUBY'
          $evm.root['miq_api_token'] = MIQ_API_TOKEN
        RUBY
      end

      it "check if the token is acessible in the method" do
         user
         create_ae_model_with_method(:name => 'FLINTSTONE', :ae_namespace => 'FRED',
                                     :ae_class => 'WILMA', :instance_name => 'DOGMATIX',
                                     :method_name => 'OBELIX',
                                     :method_script => token_script)
         ws = MiqAeEngine.instantiate("/FRED/WILMA/DOGMATIX", user)
         expect(ws.root['miq_api_token']).not_to be_nil
      end
    end
  end
end
