class WwpnCandidate < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :physical_storage
end
