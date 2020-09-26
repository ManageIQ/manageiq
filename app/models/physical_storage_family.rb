class PhysicalStorageFamily < ApplicationRecord
  # include_concern 'Operations'

  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include AvailabilityMixin
  include SupportsFeatureMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  has_many :physical_storages, :dependent => :nullify

  acts_as_miq_taggable

end
