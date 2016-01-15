class CloudObjectStoreContainer < ApplicationRecord
  include ReportableMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :cloud_tenant
  has_many   :cloud_object_store_objects

  acts_as_miq_taggable

  alias_attribute :name, :key
end
