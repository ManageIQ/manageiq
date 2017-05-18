describe ManageIQ::Providers::CloudManager::OrchestrationStack do
  let!(:root_stack) do
    FactoryGirl.create(:orchestration_stack_cloud).tap do |stack|
      FactoryGirl.create(:vm_cloud, :orchestration_stack => stack)
      FactoryGirl.create(:cloud_network, :orchestration_stack => stack)
      FactoryGirl.create(:security_group, :orchestration_stack => stack)
    end
  end

  let!(:child_stack) do
    FactoryGirl.create(:orchestration_stack_cloud, :parent => root_stack).tap do |stack|
      FactoryGirl.create(:vm_cloud, :orchestration_stack => stack)
      FactoryGirl.create(:cloud_network, :orchestration_stack => stack)
      FactoryGirl.create(:security_group, :orchestration_stack => stack)
    end
  end

  describe 'direct_<resource> methods' do
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

  describe '#service and #direct_service' do
    let(:root_service)  { FactoryGirl.create(:service) }
    let(:child_service) { FactoryGirl.create(:service, :parent => root_service) }
    before { child_service.add_resource!(root_stack) }

    it 'finds the service for the stack' do
      expect(root_stack.service).to eq(root_service)
      expect(root_stack.direct_service).to eq(child_service)
    end

    it 'finds the service for the nested stack' do
      expect(child_stack.service).to eq(root_service)
      expect(child_stack.direct_service).to eq(child_service)
    end
  end
end
