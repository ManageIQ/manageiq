class ServiceInstance < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id", :inverse_of => :service_instances
  belongs_to :service_offering
  belongs_to :service_parameters_set
end
