require 'spec_helper'

describe "Orchestration retirement state machine Methods Validation" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:ws) do
    @ae_state   = {'stack_exists_in_provider' => stack_in_provider}
    MiqAeEngine.instantiate("/Cloud/Orchestration/Retirement/StateMachines/Methods/#{method_name}?" \
      "OrchestrationStack::orchestration_stack=#{stack.id}" \
      "&ae_state_data=#{URI.escape(YAML.dump(@ae_state))}", user)
  end

  let(:stack) do
    FactoryGirl.create(:orchestration_stack)
  end

  let(:stack_in_provider) { true }

  describe "#start_retirement" do
    let(:method_name) { "StartRetirement" }

    it "starts a retirement request" do
      ws
      OrchestrationStack.where(:id => stack.id).first.retirement_state.should == 'retiring'
    end

    it "aborts if stack is already retired" do
      stack.update_attributes(:retired => true)
      expect { ws }.to raise_error(MiqAeException::AbortInstantiation, 'Method exited with rc=MIQ_ABORT')
    end

    it "aborts if stack is retiring" do
      stack.update_attributes(:retirement_state => 'retiring')
      expect { ws }.to raise_error(MiqAeException::AbortInstantiation, 'Method exited with rc=MIQ_ABORT')
    end
  end

  describe "#remove_from_provider" do
    let(:method_name) { "RemoveFromProvider" }

    it "requests stack to be deleted from provider if stack exists in provider" do
      OrchestrationStack.any_instance.stub(:raw_exists?) { true }
      OrchestrationStack.any_instance.should_receive(:raw_delete_stack)
      ws
    end

    it "does nothing if stack no longer exists in provider" do
      OrchestrationStack.any_instance.stub(:raw_exists?) { false }
      OrchestrationStack.any_instance.should_not_receive(:raw_delete_stack)
      ws
    end
  end

  describe "#check_removed_from_provider" do
    let(:method_name) { "CheckRemovedFromProvider" }

    it "completes the step when stack is removed from provider" do
      status = ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack::Status.new('DELETE_COMPLETE', nil)
      OrchestrationStack.any_instance.stub(:raw_status) { status }
      ws.root['ae_result'].should == 'ok'
    end

    it "completes the step when stack no longer exists" do
      OrchestrationStack.any_instance.stub(:raw_status) { raise MiqException::MiqOrchestrationStackNotExistError, 'stack not exist' }
      ws.root['ae_result'].should == "ok"
    end

    it "retries if stack has not been removed from provider" do
      status = ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack::Status.new('DELETING', nil)
      OrchestrationStack.any_instance.stub(:raw_status) { status }
      ws.root['ae_result'].should == 'retry'
    end

    it "reports error if cannot get stack status" do
      OrchestrationStack.any_instance.stub(:raw_status) { raise "an error" }
      ws.root['ae_result'].should == 'error'
    end
  end

  describe "#delete_from_vmdb" do
    let(:method_name) { "DeleteFromVmdb" }
    let(:stack_in_provider) { false }

    it "deletes stack from vmdb" do
      ws
      OrchestrationStack.where(:id => stack.id).first.should be_nil
    end
  end
end
