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
    $log.info("#{log_header} Manual placement...")
    return selected_placement_obj(:placement_host_name, Host),
           selected_placement_obj(:placement_ds_name, Storage)
  end

  def automatic_placement
    log_header = "MIQ(#{self.class.name}.automatic_placement)"
    # get most suitable host and datastore for new VM
    $log.info("#{log_header} Getting most suitable host and datastore for new VM from automate...")
    host, datastore = get_most_suitable_host_and_storage
    $log.info("#{log_header} Host Name: [#{host.name}] Id: [#{host.id}]") if host
    $log.info("#{log_header} Datastore Name: [#{datastore.name}] ID : [#{datastore.id}]") if datastore
    host      ||= selected_placement_obj(:placement_host_name, Host)
    datastore ||= selected_placement_obj(:placement_ds_name, Storage)
    return host, datastore
  end

  def selected_placement_obj(key, klass)
    klass.where(:id => get_option(key)).first.tap do |obj|
      raise MiqException::MiqProvisionError, "Destination #{key} not provided" unless obj
      log_header = "MIQ(#{self.class.name}.selected_placement_obj)"
      $log.info("#{log_header} Using selected #{key} : [#{obj.name}] id : [#{obj.id}]")
    end
  end
end
