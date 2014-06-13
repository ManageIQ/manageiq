class VmMigrateTask < MiqRequestTask
  alias_attribute :vm, :source

  include ReportableMixin

  validates_inclusion_of :request_type, :in => self.request_class::REQUEST_TYPES,                          :message => "should be #{self.request_class::REQUEST_TYPES.join(", ")}"
  validates_inclusion_of :state,        :in => %w{ pending finished } + self.request_class::ACTIVE_STATES, :message => "should be pending, #{self.request_class::ACTIVE_STATES.join(", ")} or finished"

  AUTOMATE_DRIVES  = true

  def self.base_model
    VmMigrateTask
  end

  def self.get_description(req_obj)
    name = nil
    if req_obj.source.nil?
      # Single source has not been selected yet
      if req_obj.options[:src_ids].length == 1
        v = Vm.find_by_id(req_obj.options[:src_ids].first)
        name = v.nil? ? "" : v.name
      else
        name = "Multiple VMs"
      end
    else
      name = req_obj.source.name
    end

    new_settings = []
    host_name = req_obj.get_option_last(:placement_host_name)
    new_settings << "Host: #{host_name}" unless host_name.blank?
    respool_name = req_obj.get_option_last(:placement_rp_name)
    new_settings << "Resource Pool: #{respool_name}" unless respool_name.blank?
    storage = req_obj.get_option_last(:placement_ds_name)
    new_settings << "Storage: #{storage}" unless storage.blank?
    return "#{self.request_class::TASK_DESCRIPTION} for: #{name} - #{new_settings.join(", ")}"
  end

  def after_request_task_create
    self.update_attribute(:description, self.get_description)
  end

  def do_request
    log_header = "MIQ(#{self.class.name}.do_request)"

    host_id = get_option(:placement_host_name)
    host = Host.find_by_id(host_id)

    respool_id = get_option(:placement_rp_name)
    respool = ResourcePool.find_by_id(respool_id)

    datastore_id = get_option(:placement_ds_name)
    datastore = Storage.find_by_id(datastore_id)

    disk_transform = case get_option(:disk_format)
    when 'thin'  then VimString.new('sparse', "VirtualMachineRelocateTransformation")
    when 'thick' then VimString.new('flat', "VirtualMachineRelocateTransformation")
    else nil
    end

    # Determine if we call migrate for relocate
    vc_method = if datastore || disk_transform
      :relocate
    elsif respool && host.nil?
      :relocate
    else
      :migrate
    end

    $log.warn "#{log_header} Calling VM #{vc_method} for #{self.vm.id}:#{self.vm.name}"
    if vc_method == :migrate
      self.vm.migrate(host, respool)
    else
      self.vm.relocate(host, respool, datastore, nil, disk_transform)
    end

    if AUTOMATE_DRIVES
      update_and_notify_parent(:state => 'migrated', :message => "Finished #{self.request_class::TASK_DESCRIPTION}")
    else
      update_and_notify_parent(:state => 'finished', :message => "#{self.request_class::TASK_DESCRIPTION} complete")
#        call_automate_event('vm_provision_postprocessing')
    end
  end

end
