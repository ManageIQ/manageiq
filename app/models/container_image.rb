class ContainerImage < ActiveRecord::Base
  include ReportableMixin

  belongs_to :container_image_registry
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many :containers
end
