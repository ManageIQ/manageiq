require 'shared/presenters/tree_node/common'

describe TreeNode::ConfiguredSystem do
  subject { described_class.new(object, nil, {}) }

  %i(
    configured_system
    configured_system_foreman
    configured_system_ansible_tower
  ).each do |factory|
    klass = FactoryGirl.factory_by_name(factory).instance_variable_get(:@class_name)
    context(klass) do
      let(:object) { FactoryGirl.create(factory) }

      include_examples 'TreeNode::Node#key prefix', 'cs-'
      include_examples 'TreeNode::Node#image', '100/configured_system.png'
      include_examples 'TreeNode::Node#tooltip prefix', 'Configured System'
    end
  end
end
