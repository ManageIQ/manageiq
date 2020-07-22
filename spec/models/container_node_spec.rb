RSpec.describe ContainerNode do
  subject { FactoryBot.create(:container_node) }

  include_examples "MiqPolicyMixin"
end
