class ContainerReplicator < ActiveRecord::Base
  include CustomAttributeMixin
  include ReportableMixin

  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_many :container_groups
  belongs_to :container_project
  has_many :labels, -> { where(:section => "labels") }, :class_name => "CustomAttribute", :as => :resource, :dependent => :destroy
  has_many :selector_parts, -> { where(:section => "selectors") }, :class_name => "CustomAttribute", :as => :resource, :dependent => :destroy
  has_many :container_nodes, -> { distinct }, :through => :container_groups

  acts_as_miq_taggable
end
