class CloudObjectStoreObject < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ExtManagementSystem"
  belongs_to :cloud_tenant
  belongs_to :cloud_object_store_container

  acts_as_miq_taggable

  alias_attribute :name, :key
end
