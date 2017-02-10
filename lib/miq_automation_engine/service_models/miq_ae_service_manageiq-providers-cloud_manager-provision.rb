module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_CloudManager_Provision < MiqAeServiceMiqProvision
    expose_eligible_resources :availability_zones
    expose_eligible_resources :instance_types
    expose_eligible_resources :security_groups, :multiple_value => true
    expose_eligible_resources :floating_ip_addresses
    expose_eligible_resources :cloud_networks
    expose_eligible_resources :cloud_subnets
    expose_eligible_resources :guest_access_key_pairs
    expose_eligible_resources :cloud_tenants
  end
end
