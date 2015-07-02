class ContainerProject < ActiveRecord::Base
  include CustomAttributeMixin
  include ReportableMixin
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many :container_groups
  has_many :container_routes
  has_many :container_replicators
  has_many :container_services

  has_many :labels, -> { where(:section => "labels") }, :class_name => "CustomAttribute", :as => :resource
end
