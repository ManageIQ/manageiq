require 'shared/presenters/tree_node/common'

describe TreeNode::EmsCluster do
  subject { described_class.new(object, nil, {}) }

  %i(ems_cluster ems_cluster_openstack).each do |factory|
    klass = FactoryGirl.factory_by_name(factory).instance_variable_get(:@class_name)
    context(klass) do
      let(:object) { FactoryGirl.create(factory) }

      include_examples 'TreeNode::Node#key prefix', 'c-'
      include_examples 'TreeNode::Node#image', '100/cluster.png'
      include_examples 'TreeNode::Node#tooltip prefix', 'Cluster / Deployment Role'
    end
  end
end
