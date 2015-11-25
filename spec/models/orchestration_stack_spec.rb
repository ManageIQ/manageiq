require "spec_helper"

describe OrchestrationStack do
  describe 'direct_<resource> methods' do
    let(:root_stack) do
      stack1 = FactoryGirl.create(:orchestration_stack)
      stack2 = FactoryGirl.create(:orchestration_stack, :parent => stack1)

      FactoryGirl.create(:vm_cloud, :orchestration_stack => stack1)
      FactoryGirl.create(:cloud_network, :orchestration_stack => stack1)
      FactoryGirl.create(:security_group, :orchestration_stack => stack1)

      FactoryGirl.create(:vm_cloud, :orchestration_stack => stack2)
      FactoryGirl.create(:cloud_network, :orchestration_stack => stack2)
      FactoryGirl.create(:security_group, :orchestration_stack => stack2)

      stack1
    end

    it 'defines a set of methods for vms' do
      root_stack.direct_vms.size.should == 1
      root_stack.vms.size.should == 2
      root_stack.total_vms.should == 2
    end

    it 'defines a set of methods for cloud_networks' do
      root_stack.direct_cloud_networks.size.should == 1
      root_stack.cloud_networks.size.should == 2
      root_stack.total_cloud_networks.should == 2
    end

    it 'defines a set of methods for security_groups' do
      root_stack.direct_security_groups.size.should == 1
      root_stack.security_groups.size.should == 2
      root_stack.total_security_groups.should == 2
    end
  end
end
