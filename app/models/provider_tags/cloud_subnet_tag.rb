class CloudSubnetTag < ProviderTag
  belongs_to :cloud_subnet, :foreign_key => :resource_id, :primary_key => :ems_ref
end
