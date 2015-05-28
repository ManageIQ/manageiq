class ContainerReplicator < ActiveRecord::Base
  include CustomAttributeMixin

  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_many :container_groups
  has_many :labels, :class_name => CustomAttribute, :as => :resource, :conditions => {:section => "labels"}
  has_many :selector_parts, :class_name => CustomAttribute, :as => :resource, :conditions => {:section => "selectors"}
end
