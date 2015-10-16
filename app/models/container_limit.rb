class ContainerLimit < ActiveRecord::Base
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :container_project

  has_many :container_limit_items, :dependent => :destroy
end
