require 'shared/presenters/tree_node/common'

describe TreeNode::EmsFolder do
  subject { described_class.new(object, nil, options) }
  let(:options) { Hash.new }

  %i(
    ems_folder
    storage_cluster
    inventory_group
    inventory_root_group
  ).each do |factory|
    klass = FactoryGirl.factory_by_name(factory).instance_variable_get(:@class_name)
    context(klass) do
      let(:object) { FactoryGirl.create(factory) }

      include_examples 'TreeNode::Node#key prefix', 'f-'
      include_examples 'TreeNode::Node#image', '100/folder.png'
      include_examples 'TreeNode::Node#tooltip prefix', 'Folder'

      context 'type is vat' do
        let(:options) { {:type => :vat} }

        include_examples 'TreeNode::Node#image', '100/blue_folder.png'
      end
    end
  end

  context 'Datacenter' do
    let(:object) { FactoryGirl.create(:datacenter) }

    include_examples 'TreeNode::Node#key prefix', 'dc-'
    include_examples 'TreeNode::Node#image', '100/datacenter.png'
    include_examples 'TreeNode::Node#tooltip prefix', 'Datacenter'
  end
end
