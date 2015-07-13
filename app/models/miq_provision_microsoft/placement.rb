module MiqProvisionMicrosoft::Placement
  extend ActiveSupport::Concern

  protected

  def placement
    host, datastore = placement_auto ? automatic_placement : manual_placement

    options[:dest_host]    = [host.id, host.name]
    options[:dest_storage] = [datastore.id, datastore.name]

    return host, datastore
  end

  private

  def manual_placement
    _log.info("Manual placement...")
    return selected_placement_obj(:placement_host_name, Host),
           selected_placement_obj(:placement_ds_name, Storage)
  end

  def automatic_placement
    # get most suitable host and datastore for new VM
    _log.info("Getting most suitable host and datastore for new VM from automate...")
    host, datastore = get_most_suitable_host_and_storage
    _log.info("Host Name: [#{host.name}] Id: [#{host.id}]") if host
    _log.info("Datastore Name: [#{datastore.name}] ID : [#{datastore.id}]") if datastore
    host      ||= selected_placement_obj(:placement_host_name, Host)
    datastore ||= selected_placement_obj(:placement_ds_name, Storage)
    return host, datastore
  end

  def selected_placement_obj(key, klass)
    klass.where(:id => get_option(key)).first.tap do |obj|
      raise MiqException::MiqProvisionError, "Destination #{key} not provided" unless obj
      _log.info("Using selected #{key} : [#{obj.name}] id : [#{obj.id}]")
    end
  end
end
