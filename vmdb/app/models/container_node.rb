class ContainerNode < ActiveRecord::Base
  # :name, :uid, :creation_timestamp, :resource_version
  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_many :container_groups
end
