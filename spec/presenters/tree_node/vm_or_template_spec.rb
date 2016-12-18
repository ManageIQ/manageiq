require 'shared/presenters/tree_node/common'

describe TreeNode::VmOrTemplate do
  subject { described_class.new(object, nil, {}) }

  # FIXME: make this dynamic somehow by using VmOrTemplate.descendants
  # Template classes
  %i(
    miq_template
    template_cloud
    template_infra
    template_amazon
    template_azure
    template_google
    template_openstack
    template_vmware_cloud
    template_microsoft
    template_redhat
    template_vmware
    template_xen
  ).each do |factory|
    klass = FactoryGirl.factory_by_name(factory).instance_variable_get(:@class_name)
    context(klass) do
      let(:object) { FactoryGirl.create(factory, :name => "template", :template => true) }

      include_examples 'TreeNode::Node#key prefix', 't-'
      include_examples 'TreeNode::Node#image', '100/currentstate-archived.png'

      describe '#tooltip' do
        it 'returns with nil' do
          expect(subject.tooltip).to be_nil
        end
      end
    end
  end

  # Vm classes
  %i(
    vm
    vm_cloud
    vm_infra
    vm_server
    vm_amazon
    vm_azure
    vm_google
    vm_openstack
    vm_vmware_cloud
    vm_microsoft
    vm_redhat
    vm_vmware
    vm_xen
  ).each do |factory|
    klass = FactoryGirl.factory_by_name(factory).instance_variable_get(:@class_name)
    context(klass) do
      let(:object) { FactoryGirl.create(factory) }

      include_examples 'TreeNode::Node#key prefix', 'v-'
      include_examples 'TreeNode::Node#image', '100/currentstate-archived.png'

      describe '#tooltip' do
        it 'returns with the correct prefix and suffix' do
          expect(subject.tooltip).to eq("VM: #{object.name} (Click to view)")
        end
      end
    end
  end
end
