require 'shared/presenters/tree_node/common'

describe TreeNode::Host do
  subject { described_class.new(object, nil, {}) }

  %i(
    host
    host_microsoft
    host_redhat
    host_openstack_infra
    host_vmware
    host_vmware_esx
  ).each do |factory|
    klass = FactoryGirl.factory_by_name(factory).instance_variable_get(:@class_name)
    context(klass) do
      let(:object) { FactoryGirl.create(factory) }

      include_examples 'TreeNode::Node#key prefix', 'h-'
      include_examples 'TreeNode::Node#image', '100/host.png'
      include_examples 'TreeNode::Node#tooltip prefix', 'Host / Node'
    end
  end
end
