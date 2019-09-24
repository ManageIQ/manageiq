module ManageIQ::Providers::CloudManager::Provision::Cloning
  def find_destination_in_vmdb(ems_ref)
    vm_model_class.find_by(:ems_id => source.ext_management_system.id, :ems_ref => ems_ref)
  end

  def vm_model_class
    self.class.parent::Vm
  end

  def validate_dest_name
    raise MiqException::MiqProvisionError, _("Provision Request's Destination Name cannot be blank") if dest_name.blank?
    if source.ext_management_system.vms.where(:name => dest_name).any?
      raise MiqException::MiqProvisionError, _("A VM with name: [%{name}] already exists") % {:name => dest_name}
    end
  end

  def prepare_for_clone_task
    validate_dest_name

    clone_options = {}
    clone_options[:key_name]          = guest_access_key_pair.try(:name) if guest_access_key_pair
    clone_options[:availability_zone] = dest_availability_zone.ems_ref   if dest_availability_zone

    user_data = userdata_payload
    clone_options[:user_data] = user_data unless user_data.blank?

    clone_options
  end
end
