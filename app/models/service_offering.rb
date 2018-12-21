class ServiceOffering < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id", :inverse_of => :service_offerings

  has_many :service_instances, :dependent => :nullify
  has_many :service_parameters_sets, :dependent => :nullify
end
