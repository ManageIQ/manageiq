require 'shared/presenters/tree_node/common'

describe TreeNode::Container do
  subject { described_class.new(object, nil, {}) }

  %i(container kubernetes_container).each do |factory|
    klass = FactoryGirl.factory_by_name(factory).instance_variable_get(:@class_name)
    context(klass) do
      let(:object) { FactoryGirl.create(factory) }

      include_examples 'TreeNode::Node#key prefix', 'cnt-'
      include_examples 'TreeNode::Node#image', '100/container.png'
    end
  end
end
