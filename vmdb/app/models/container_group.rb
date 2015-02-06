class ContainerGroup < ActiveRecord::Base
  # :name, :uid, :creation_timestamp, :resource_version, :namespace
  # :labels, :restart_policy, :dns_policy

  has_many :containers
  has_many :container_definitions
  belongs_to  :ext_management_system, :foreign_key => "ems_id"

  # validates :restart_policy, :inclusion => { :in => %w(always onFailure never) }
  # validates :dns_policy, :inclusion => { :in => %w(ClusterFirst Default) }
end
