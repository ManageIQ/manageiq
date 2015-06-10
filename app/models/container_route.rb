class ContainerRoute < ActiveRecord::Base
  include CustomAttributeMixin
  include ReportableMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :container_services
  has_many :labels, :class_name => CustomAttribute, :as => :resource, :conditions => {:section => "labels"}
end
