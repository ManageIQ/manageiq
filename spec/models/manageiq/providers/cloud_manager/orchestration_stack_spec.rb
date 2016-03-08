describe ManageIQ::Providers::CloudManager::OrchestrationStack do
  describe 'direct_<resource> methods' do
    let(:root_stack) do
      stack1 = FactoryGirl.create(:orchestration_stack_cloud)
      stack2 = FactoryGirl.create(:orchestration_stack_cloud, :parent => stack1)

      FactoryGirl.create(:vm_cloud, :orchestration_stack => stack1)
      FactoryGirl.create(:cloud_network, :orchestration_stack => stack1)
      FactoryGirl.create(:security_group, :orchestration_stack => stack1)

      FactoryGirl.create(:vm_cloud, :orchestration_stack => stack2)
      FactoryGirl.create(:cloud_network, :orchestration_stack => stack2)
      FactoryGirl.create(:security_group, :orchestration_stack => stack2)

      stack1
    end

    it 'defines a set of methods for vms' do
      expect(root_stack.direct_vms.size).to eq(1)
      expect(root_stack.vms.size).to eq(2)
      expect(root_stack.total_vms).to eq(2)
    end

    it 'defines a set of methods for cloud_networks' do
      expect(root_stack.direct_cloud_networks.size).to eq(1)
      expect(root_stack.cloud_networks.size).to eq(2)
      expect(root_stack.total_cloud_networks).to eq(2)
    end

    it 'defines a set of methods for security_groups' do
      expect(root_stack.direct_security_groups.size).to eq(1)
      expect(root_stack.security_groups.size).to eq(2)
      expect(root_stack.total_security_groups).to eq(2)
    end
  end
end
