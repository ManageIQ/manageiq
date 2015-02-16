class ContainerService < ActiveRecord::Base
  include CustomAttributeMixin
  # :name, :uid, :creation_timestamp, :resource_version, :namespace
  # :labels, :selector, :protocol, :port, :container_port, :portal_ip, :session_affinity

  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_many :container_groups
  has_many :labels, :class_name => CustomAttribute, :as => :resource, :conditions => {:section => "labels"}
  has_many :selector_parts, :class_name => CustomAttribute, :as => :resource, :conditions => {:section => "selectors"}
end
