RSpec.describe ContainerProject do
  subject { FactoryBot.create(:container_project) }

  include_examples "MiqPolicyMixin"
end
