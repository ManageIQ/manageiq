describe "LoadBalancer retirement state machine Methods Validation" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:ws) do
    @ae_state   = {'load_balancer_exists_in_provider' => load_balancer_in_provider}
    MiqAeEngine.instantiate("/Cloud/LoadBalancer/Retirement/StateMachines/Methods/#{method_name}?" \
      "LoadBalancer::load_balancer=#{load_balancer.id}" \
      "&ae_state_data=#{URI.escape(YAML.dump(@ae_state))}", user)
  end

  let(:load_balancer) do
    FactoryGirl.create(:load_balancer_amazon)
  end

  let(:load_balancer_in_provider) { true }

  describe "#start_retirement" do
    let(:method_name) { "StartRetirement" }

    it "starts a retirement request" do
      ws
      expect(LoadBalancer.where(:id => load_balancer.id).first.retirement_state).to eq('retiring')
    end

    it "aborts if load_balancer is already retired" do
      load_balancer.update_attributes(:retired => true)
      expect { ws }.to raise_error(MiqAeException::AbortInstantiation, 'Method exited with rc=MIQ_ABORT')
    end

    it "aborts if load_balancer is retiring" do
      load_balancer.update_attributes(:retirement_state => 'retiring')
      expect { ws }.to raise_error(MiqAeException::AbortInstantiation, 'Method exited with rc=MIQ_ABORT')
    end
  end

  describe "#remove_from_provider" do
    let(:method_name) { "RemoveFromProvider" }

    it "requests load_balancer to be deleted from provider if load_balancer exists in provider" do
      allow_any_instance_of(LoadBalancer).to receive(:raw_exists?) { true }
      expect_any_instance_of(LoadBalancer).to receive(:raw_delete_load_balancer)
      ws
    end

    it "does nothing if load_balancer no longer exists in provider" do
      allow_any_instance_of(LoadBalancer).to receive(:raw_exists?) { false }
      expect_any_instance_of(LoadBalancer).not_to receive(:raw_delete_load_balancer)
      ws
    end
  end

  describe "#check_removed_from_provider" do
    let(:method_name) { "CheckRemovedFromProvider" }

    it "completes the step when load_balancer no longer exists or is removed from a provider" do
      allow_any_instance_of(LoadBalancer)
        .to receive(:raw_status) { raise MiqException::MiqLoadBalancerNotExistError, 'load_balancer not exist' }
      expect(ws.root['ae_result']).to eq("ok")
    end

    it "retries if load_balancer has not been removed from provider" do
      allow_any_instance_of(LoadBalancer).to receive(:raw_status) { 'DELETING' }
      expect(ws.root['ae_result']).to eq('retry')
    end

    it "reports error if cannot get load_balancer status" do

      allow_any_instance_of(LoadBalancer).to receive(:raw_status) { raise "an error" }
      # The exit affects the error state, if method is called directly
      expect(ws.root).to eq(nil)
    end
  end

  describe "#delete_from_vmdb" do
    let(:method_name) { "DeleteFromVmdb" }
    let(:load_balancer_in_provider) { false }

    it "deletes load_balancer from vmdb" do
      ws
      expect(LoadBalancer.where(:id => load_balancer.id).first).to be_nil
    end
  end
end
