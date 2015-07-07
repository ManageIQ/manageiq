class ContainerRoute < ActiveRecord::Base
  include CustomAttributeMixin
  include ReportableMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many :labels, -> { where(:section => "labels") }, :class_name => "CustomAttribute", :as => :resource 
  belongs_to :container_service
  has_many :labels, :class_name => CustomAttribute, :as => :resource, :conditions => {:section => "labels"}
end
