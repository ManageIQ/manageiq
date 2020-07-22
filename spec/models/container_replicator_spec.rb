RSpec.describe ContainerReplicator do
  subject { FactoryBot.create(:container_replicator) }

  include_examples "MiqPolicyMixin"
end
