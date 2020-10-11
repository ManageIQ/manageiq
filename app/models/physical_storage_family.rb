class PhysicalStorageFamily < ApplicationRecord
  # include_concern 'Operations'

  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include AvailabilityMixin
  include SupportsFeatureMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  has_many :physical_storages, :dependent => :nullify

  acts_as_miq_taggable

  def self.class_by_ems(ext_management_system)
    # TODO(lsmola) taken from OrchesTration stacks, correct approach should be to have a factory on ExtManagementSystem
    # side, that would return correct class for each provider
    ext_management_system && ext_management_system.class::physicalStorageFamily
  end
end
