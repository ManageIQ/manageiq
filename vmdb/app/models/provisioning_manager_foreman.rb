class ProvisioningManagerForeman < ProvisioningManager
  delegate :connection_attrs, :to => :provider
end
