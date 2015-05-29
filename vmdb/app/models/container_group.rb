class ContainerGroup < ActiveRecord::Base
  include CustomAttributeMixin
  include ReportableMixin
  # :name, :uid, :creation_timestamp, :resource_version, :namespace
  # :labels, :restart_policy, :dns_policy

  has_many :containers, :dependent => :destroy
  has_many :container_definitions, :dependent => :destroy
  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_many :labels, :class_name => CustomAttribute, :as => :resource, :conditions => {:section => "labels"}
  belongs_to :container_node
  has_and_belongs_to_many :container_services
  belongs_to :container_replicator

  # validates :restart_policy, :inclusion => { :in => %w(always onFailure never) }
  # validates :dns_policy, :inclusion => { :in => %w(ClusterFirst Default) }
end
