class StorageService < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin
  include CustomActionsMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id,
                                     :class_name  => "ExtManagementSystem"
  has_many :storage_service_resource_attachments, :inverse_of => :storage_service, :dependent => :destroy
  has_many :storage_resources, :through => :storage_service_resource_attachments
  has_many :cloud_volumes

  has_many :storage_service_capabilities, :foreign_key => :service_uuid
  has_many :capability_values, :through => :storage_service_capabilities

  acts_as_miq_taggable

  def self.class_by_ems(ext_management_system)
    ext_management_system&.class_by_ems(:StorageService)
  end
end
