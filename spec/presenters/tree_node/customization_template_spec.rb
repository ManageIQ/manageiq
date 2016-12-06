require 'shared/presenters/tree_node/common'

describe TreeNode::CustomizationTemplate do
  subject { described_class.new(object, nil, {}) }

  %i(
    customization_template
    customization_template_kickstart
    customization_template_sysprep
    customization_template_cloud_init
  ).each do |factory|
    klass = FactoryGirl.factory_by_name(factory).instance_variable_get(:@class_name)
    context(klass) do
      let(:object) { FactoryGirl.create(factory) }

      include_examples 'TreeNode::Node#key prefix', 'ct-'
      include_examples 'TreeNode::Node#image', '100/customizationtemplate.png'
    end
  end
end
