class WwpnCandidate < ApplicationRecord
  belongs_to :ext_management_system
  belongs_to :physical_storage
end
