require 'shared/presenters/tree_node/common'

describe TreeNode::IsoDatastore do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:iso_datastore) }

  include_examples 'TreeNode::Node#key prefix', 'isd-'
  include_examples 'TreeNode::Node#image', '100/isodatastore.png'
end
