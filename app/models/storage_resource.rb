class StorageResource < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin
  include CustomActionsMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :physical_storage, :inverse_of => :storage_resources

  has_many :storage_service_resource_attachments, :inverse_of => :storage_resource, :dependent => :destroy
  has_many :storage_services, :through => :storage_service_resource_attachments, :dependent => :destroy

  has_many :cloud_volumes, :inverse_of => :storage_resource, :dependent => :destroy

  acts_as_miq_taggable

  def self.class_by_ems(ext_management_system)
    # TODO(lsmola) taken from Orchestration stacks, correct approach should be to have a factory on ExtManagementSystem
    # side, that would return correct class for each provider
    ext_management_system && ext_management_system.class::StorageResource
  end
end
