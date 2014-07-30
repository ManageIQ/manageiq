class CloudObjectStoreObject < ActiveRecord::Base
  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :cloud_tenant
  belongs_to :cloud_object_store_container
end
