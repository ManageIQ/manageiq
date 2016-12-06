require 'shared/presenters/tree_node/common'

describe TreeNode::PxeImage do
  subject { described_class.new(object, nil, {}) }

  %i(
    pxe_image
    pxe_image_ipxe
    pxe_image_pxelinux
  ).each do |factory|
    klass = FactoryGirl.factory_by_name(factory).instance_variable_get(:@class_name)
    context(klass) do
      let(:object) { FactoryGirl.create(factory) }

      include_examples 'TreeNode::Node#key prefix', 'pi-'
      include_examples 'TreeNode::Node#image', '100/pxeimage.png'
    end
  end
end
