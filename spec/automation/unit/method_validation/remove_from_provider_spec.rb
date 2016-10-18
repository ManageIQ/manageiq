describe "remove_from_provider Method Validation" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:zone) { FactoryGirl.create(:zone) }

  context "Infrastructure" do
    let(:ems) { FactoryGirl.create(:ems_vmware, :zone => zone) }
    let(:vm) { FactoryGirl.create(:vm_vmware, :ems_id => ems.id) }
    let(:ws) do
      MiqAeEngine.instantiate("/Infrastructure/VM/Retirement/StateMachines/Methods/RemoveFromProvider?" \
                              "Vm::vm=#{vm.id}", user)
    end

    it "vm without tags" do
      ws
      expect(
        MiqQueue.exists?(:method_name => 'vm_destroy',
                         :instance_id => vm.id,
                         :role        => 'ems_operations')
      ).to be_falsey
    end

    it "nil vm " do
      ws
      expect(
        MiqQueue.exists?(:method_name => 'vm_destroy',
                         :role        => 'ems_operations')
      ).to be_falsey
    end

    it "vm without an ems" do
      vm.update_attributes(:ext_management_system => nil)
      ws
      expect(
        MiqQueue.exists?(:method_name => 'vm_destroy',
                         :instance_id => vm.id,
                         :role        => 'ems_operations')
      ).to be_falsey
    end

    it "removes a vm" do
      vm.tag_with("retire_full", :ns => "/managed", :cat => "lifecycle")
      ws
      expect(
        MiqQueue.exists?(:method_name => 'vm_destroy',
                         :instance_id => vm.id,
                         :role        => 'ems_operations')
      ).to be_truthy
    end
  end

  context "Cloud" do
    let(:ems) { FactoryGirl.create(:ems_google, :zone => zone) }
    let(:vm) { FactoryGirl.create(:vm_google, :ems_id => ems.id) }
    let(:ws) do
      MiqAeEngine.instantiate("/Cloud/VM/Retirement/StateMachines/Methods/RemoveFromProvider?" \
                              "Vm::vm=#{vm.id}", user)
    end

    it "vm without tags" do
      ws
      expect(
        MiqQueue.exists?(:method_name => 'vm_destroy',
                         :instance_id => vm.id,
                         :role        => 'ems_operations')
      ).to be_falsey
    end

    it "nil vm " do
      ws
      expect(
        MiqQueue.exists?(:method_name => 'vm_destroy',
                         :role        => 'ems_operations')
      ).to be_falsey
    end

    it "vm without an ems" do
      vm.update_attributes(:ext_management_system => nil)
      ws
      expect(
        MiqQueue.exists?(:method_name => 'vm_destroy',
                         :instance_id => vm.id,
                         :role        => 'ems_operations')
      ).to be_falsey
    end

    it "removes a vm" do
      vm.tag_with("retire_full", :ns => "/managed", :cat => "lifecycle")
      ws
      expect(
        MiqQueue.exists?(:method_name => 'vm_destroy',
                         :instance_id => vm.id,
                         :role        => 'ems_operations')
      ).to be_truthy
    end
  end
end
