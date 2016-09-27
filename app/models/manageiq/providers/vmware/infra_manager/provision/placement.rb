module ManageIQ::Providers::Vmware::InfraManager::Provision::Placement
  extend ActiveSupport::Concern

  protected

  def placement
    host, cluster, datastore = if get_option(:placement_auto) == true
      automatic_placement
    else
      manual_placement
    end

    raise MiqException::MiqProvisionError, "Destination placement_ds_name not provided" if datastore.nil?
    raise MiqException::MiqProvisionError, "Destination placement_host_name and placement_cluster_name not provided" if host.nil? && cluster.nil?
    raise MiqException::MiqProvisionError, "A Host must be selected on a non-DRS enabled cluster" if host.nil? && !cluster.drs_enabled

    return host, cluster, datastore
  end

  private

  def manual_placement
    _log.info("Manual placement...")

    host      = selected_placement_obj(:placement_host_name, Host)
    cluster   = selected_placement_obj(:placement_cluster_name, EmsCluster)
    datastore = selected_placement_obj(:placement_ds_name, Storage)

    if host && cluster.nil?
      cluster = host.ems_cluster
    end

    return host, cluster, datastore
  end

  def automatic_placement
    # get most suitable host and datastore for new VM
    _log.info("Getting most suitable host and datastore for new VM from automate...")
    host, datastore = get_most_suitable_host_and_storage

    _log.info("Host Name: [#{host.name}] Id: [#{host.id}]") if host
    _log.info("Datastore Name: [#{datastore.name}] ID : [#{datastore.id}]") if datastore

    host      ||= selected_placement_obj(:placement_host_name, Host)
    datastore ||= selected_placement_obj(:placement_ds_name, Storage)
    cluster     = selected_placement_obj(:placement_cluster_name, EmsCluster) || host.try(:ems_cluster)

    return host, cluster, datastore
  end

  def selected_placement_obj(key, klass)
    klass.find_by(:id => get_option(key)).tap do |obj|
      _log.info("Using selected #{key} : [#{obj.name}] id : [#{obj.id}]") if obj
    end
  end
end
