module MiqProvisionVmware::Placement
  extend ActiveSupport::Concern

  include_concern 'NetApp'

  protected

  def placement
    if get_option(:placement_auto) == true
      automatic_placement
    elsif get_option(:new_datastore_create) == true
      create_netapp_datastore(source_vm_or_template) # Use NetApp to create datastore
    else
      manual_placement
    end
  end

  private

  def manual_placement
    log_header = "MIQ(#{self.class.name}.manual_placement)"

    raise MiqException::MiqProvisionError, "Destination host not provided"      if get_option(:placement_host_name).blank?
    raise MiqException::MiqProvisionError, "Destination datastore not provided" if get_option(:placement_ds_name).blank?
    host_id      = get_option(:placement_host_name)
    datastore_id = get_option(:placement_ds_name)

    $log.info("#{log_header} Using selected host and datastore for new VM, Host Id: [#{host_id}], Datastore Id: [#{datastore_id}]")
    host      = Host.find_by_id(host_id)
    datastore = Storage.find_by_id(datastore_id)
    return host, datastore
  end

  def automatic_placement
    log_header = "MIQ(#{self.class.name}.automatic_placement)"

    # get most suitable host and datastore for new VM
    $log.info("#{log_header} Getting most suitable host and datastore for new VM...")
    host, datastore = self.get_most_suitable_host_and_storage
    raise MiqException::MiqProvisionError, "Unable to find a suitable host"    if host.nil?
    raise MiqException::MiqProvisionError, "Unable to find a suitable storage" if datastore.nil?
    self.options[:placement_host_name] = [host.id, host.name]
    self.options[:placement_ds_name]   = [datastore.id, datastore.name]
    $log.info("#{log_header} Getting most suitable host and datastore for new VM...Complete, Host Id: [#{host.id}], Name: [#{host.name}], Datastore Id: [#{datastore.id}], Name: [#{datastore.name}]")
    return host, datastore
  end
end
