class FiberChannelAddress < ApplicationRecord
  include ProviderObjectMixin

  has_many :san_addresses, :as => :port

  acts_as_miq_taggable

  def self.class_by_ems(ext_management_system)
    # TODO(lsmola) taken from Orchestration stacks, correct approach should be to have a factory on ExtManagementSystem
    # side, that would return correct class for each provider
    ext_management_system && ext_management_system.class::FiberChannelAddress
  end
end
