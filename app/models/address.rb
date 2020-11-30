class Address < ApplicationRecord
  include ProviderObjectMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :physical_storage_consumer, :inverse_of => :addresses
  belongs_to :physical_storage, :inverse_of => :addresses

  acts_as_miq_taggable

  def self.class_by_ems(ext_management_system)
    # TODO(lsmola) taken from Orchestration stacks, correct approach should be to have a factory on ExtManagementSystem
    # side, that would return correct class for each provider
    ext_management_system && ext_management_system.class::Address
  end
end
