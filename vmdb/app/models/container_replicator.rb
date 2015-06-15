class ContainerReplicator < ActiveRecord::Base
  include CustomAttributeMixin
  include ReportableMixin

  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_many :container_groups
  has_many :labels, -> { where(:section => "labels") }, :class_name => "CustomAttribute", :as => :resource
  has_many :selector_parts, -> { where(:section => "selectors") }, :class_name => "CustomAttribute", :as => :resource
end
