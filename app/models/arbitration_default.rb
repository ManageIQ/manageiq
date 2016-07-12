class ArbitrationDefault < ApplicationRecord
  validates :ext_management_system, :presence => true, :uniqueness => true

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :cloud_subnet
  belongs_to :cloud_network
  belongs_to :authentication, :foreign_key => :auth_key_pair_id
  belongs_to :flavor
  belongs_to :availability_zone
  belongs_to :security_group
end
