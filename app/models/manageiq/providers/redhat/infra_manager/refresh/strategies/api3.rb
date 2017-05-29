module ManageIQ::Providers::Redhat::InfraManager::Refresh::Strategies
  class Api3 < ManageIQ::Providers::Redhat::InfraManager::Refresh::Refresher
    def host_targeted_refresh(inventory, target)
      methods = {
        :primary   => {
          :cluster => target.ems_cluster.ems_ref,
          :host    => target.ems_ref,
          :network => { :networks => "network" }
        },
        :secondary => {
          :host => [:statistics, :host_nics],
        }
      }
      inventory.targeted_refresh(methods)
    end

    def vm_targeted_refresh(inventory, target)
      require 'uri'

      vm = target.ems_ref
      vm_id = URI(vm).path.split('/').last

      methods = {
        :primary   => {
          :cluster    => {:clusters => "cluster"},
          :datacenter => {:datacenters => "data_center"},
          :vm         => vm,
          :template   => "/api/templates?search=vm.id=#{vm_id}",
          :storage    => target.storages.empty? ? {:storagedomains => "storage_domain"} : target.storages.map(&:ems_ref)
        },
        :secondary => {
          :vm       => [:disks, :snapshots, :nics],
          :template => [:disks]
        }
      }
      inventory.targeted_refresh(methods)
    end
  end
end
