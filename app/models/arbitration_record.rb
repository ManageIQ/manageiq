class ArbitrationRecord < ApplicationRecord
  self.table_name = 'arbitration_profiles'

  alias_attribute :ems_ref, :uid_ems

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :cloud_subnet
  belongs_to :cloud_network
  belongs_to :authentication
  belongs_to :flavor
  belongs_to :availability_zone
  belongs_to :security_group
end
