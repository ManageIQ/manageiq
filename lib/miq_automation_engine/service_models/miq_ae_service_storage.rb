module MiqAeMethodService
  class MiqAeServiceStorage < MiqAeServiceModelBase
    expose :ext_management_systems, :association => true
    expose :hosts,                  :association => true
    expose :vms,                    :association => true
    expose :unregistered_vms,       :association => true
    expose :storage_files,          :association => true
    expose :files,                  :association => true
    expose :storage_clusters,       :association => true
    expose :to_s
    expose :scan,                   :override_return => true
  end
end
