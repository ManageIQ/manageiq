module MiqAeMethodService
  class MiqAeServiceExtManagementSystem < MiqAeServiceModelBase
    expose :storages,       :association => true
    expose :hosts,          :association => true
    expose :vms,            :association => true
    expose :ems_events,     :association => true
    expose :ems_clusters,   :association => true
    expose :ems_folders,    :association => true
    expose :resource_pools, :association => true
    expose :to_s
    expose :authentication_userid
    expose :authentication_password
    expose :authentication_password_encrypted
    expose :refresh, :method => :refresh_ems
  end
end
