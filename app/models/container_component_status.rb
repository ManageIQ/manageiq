class ContainerComponentStatus < ActiveRecord::Base
  include ReportableMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"
end
