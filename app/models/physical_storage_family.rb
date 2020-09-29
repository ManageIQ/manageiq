class PhysicalStorageFamily < ApplicationRecord
  include ProviderObjectMixin
  include SupportsFeatureMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  has_many :physical_storages, :dependent => :nullify

  acts_as_miq_taggable
end
