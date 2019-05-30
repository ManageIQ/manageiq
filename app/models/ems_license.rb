class EmsLicense < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :ems_licenses

  validates :ems_ref, :presence => true
end
