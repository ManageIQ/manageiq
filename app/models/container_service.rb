class ContainerService < ActiveRecord::Base
  include CustomAttributeMixin
  include ReportableMixin
  # :name, :uid, :creation_timestamp, :resource_version, :namespace
  # :labels, :selector, :protocol, :port, :container_port, :portal_ip, :session_affinity

  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_and_belongs_to_many :container_groups, :join_table => :container_groups_container_services
  has_many :container_routes
  has_many :container_service_port_configs, :dependent => :destroy
  has_many :labels, -> { where(:section => "labels") }, :class_name => "CustomAttribute", :as => :resource
  has_many :selector_parts, -> { where(:section => "selectors") }, :class_name => "CustomAttribute", :as => :resource
end
