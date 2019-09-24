class EmsExtension < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :ems_extensions

  validates :ems_ref, :presence => true
end
