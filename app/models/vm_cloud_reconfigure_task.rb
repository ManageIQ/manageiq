class VmCloudReconfigureTask < MiqRequestTask
  alias_attribute :vm, :source

  validate :validate_request_type, :validate_state

  AUTOMATE_DRIVES = false

  def self.base_model
    VmCloudReconfigureTask
  end

  def self.get_description(req_obj)
    name = nil
    if req_obj.source.nil?
      # Single source has not been selected yet
      if req_obj.options[:src_ids].length == 1
        v = Vm.find_by(:id => req_obj.options[:src_ids].first)
        name = v.nil? ? "" : v.name
      else
        name = "Multiple VMs"
      end
    else
      name = req_obj.source.name
    end
    flavor = Flavor.find_by(:id => req_obj.options[:instance_type])

    "#{request_class::TASK_DESCRIPTION} for: #{name} - Flavor: #{flavor.try(:name)}"
  end

  def after_request_task_create
    update(:description => get_description)
  end

  def do_request
    flavor = Flavor.find_by!(:id => options[:instance_type])
    _log.info("Reconfiguring VM #{vm.id}:#{vm.name} to flavor #{flavor.name}")
    vm.resize(options[:instance_type])

    if AUTOMATE_DRIVES
      update_and_notify_parent(:state => 'reconfigured', :message => "Finished #{request_class::TASK_DESCRIPTION}")
    else
      update_and_notify_parent(:state => 'finished', :message => "#{request_class::TASK_DESCRIPTION} complete")
    end
  end
end
