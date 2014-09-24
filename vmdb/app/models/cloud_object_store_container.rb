class CloudObjectStoreContainer < ActiveRecord::Base
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "EmsCloud"
  belongs_to :cloud_tenant
  has_many   :cloud_object_store_objects
end
