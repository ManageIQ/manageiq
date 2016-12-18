require 'shared/presenters/tree_node/common'

describe TreeNode::AvailabilityZone do
  subject { described_class.new(object, nil, {}) }

  %i(
    availability_zone_amazon
    availability_zone_azure
    availability_zone_google
    availability_zone_openstack
    availability_zone_openstack_null
    availability_zone_vmware
  ).each do |factory|
    klass = FactoryGirl.factory_by_name(factory).instance_variable_get(:@class_name)
    context(klass) do
      let(:object) { FactoryGirl.create(factory) }

      include_examples 'TreeNode::Node#key prefix', 'az-'
      include_examples 'TreeNode::Node#image', '100/availability_zone.png'
      include_examples 'TreeNode::Node#tooltip prefix', 'Availability Zone'
    end
  end
end
