describe "Orchestration retirement state machine Methods Validation" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:ws) do
    @ae_state   = {'stack_exists_in_provider' => stack_in_provider}
    MiqAeEngine.instantiate("/Cloud/Orchestration/Retirement/StateMachines/Methods/#{method_name}?" \
      "OrchestrationStack::orchestration_stack=#{stack.id}" \
      "&ae_state_data=#{URI.escape(YAML.dump(@ae_state))}", user)
  end

  let(:stack) do
    FactoryGirl.create(:orchestration_stack_cloud)
  end

  let(:stack_in_provider) { true }

  describe "#start_retirement" do
    let(:method_name) { "StartRetirement" }

    it "starts a retirement request" do
      ws
      expect(OrchestrationStack.where(:id => stack.id).first.retirement_state).to eq('retiring')
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
      allow_any_instance_of(OrchestrationStack).to receive(:raw_exists?) { true }
      expect_any_instance_of(OrchestrationStack).to receive(:raw_delete_stack)
      ws
    end

    it "does nothing if stack no longer exists in provider" do
      allow_any_instance_of(OrchestrationStack).to receive(:raw_exists?) { false }
      expect_any_instance_of(OrchestrationStack).not_to receive(:raw_delete_stack)
      ws
    end
  end

  describe "#check_removed_from_provider" do
    let(:method_name) { "CheckRemovedFromProvider" }

    it "completes the step when stack is removed from provider" do
      status = ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack::Status.new('DELETE_COMPLETE', nil)
      allow_any_instance_of(OrchestrationStack).to receive(:raw_status) { status }
      expect(ws.root['ae_result']).to eq('ok')
    end

    it "completes the step when stack no longer exists" do
      allow_any_instance_of(OrchestrationStack)
        .to receive(:raw_status) { raise MiqException::MiqOrchestrationStackNotExistError, 'stack not exist' }
      expect(ws.root['ae_result']).to eq("ok")
    end

    it "retries if stack has not been removed from provider" do
      status = ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack::Status.new('DELETING', nil)
      allow_any_instance_of(OrchestrationStack).to receive(:raw_status) { status }
      expect(ws.root['ae_result']).to eq('retry')
    end

    it "reports error if cannot get stack status" do
      allow_any_instance_of(OrchestrationStack).to receive(:raw_status) { raise "an error" }
      expect(ws.root['ae_result']).to eq('error')
    end
  end

  describe "#delete_from_vmdb" do
    let(:method_name) { "DeleteFromVmdb" }
    let(:stack_in_provider) { false }

    it "deletes stack from vmdb" do
      ws
      expect(OrchestrationStack.where(:id => stack.id).first).to be_nil
    end
  end
end
