class CloudSubnet < ActiveRecord::Base
  belongs_to :cloud_network
  belongs_to :availability_zone
  has_many   :vms
end