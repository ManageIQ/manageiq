class StorageServiceResourceAttachment < ApplicationRecord
  include ProviderObjectMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :storage_service, :inverse_of => :storage_service_resource_attachments
  belongs_to :storage_resource, :inverse_of => :storage_service_resource_attachments

  acts_as_miq_taggable
end
