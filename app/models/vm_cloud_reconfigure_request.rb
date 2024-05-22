class VmCloudReconfigureRequest < MiqRequest
  TASK_DESCRIPTION  = N_('VM Cloud Reconfigure').freeze
  SOURCE_CLASS_NAME = 'Vm'.freeze
  ACTIVE_STATES     = %w[reconfigured] + base_class::ACTIVE_STATES

  validates :request_state, :inclusion => {:in      => %w[pending finished] + ACTIVE_STATES,
                                            :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"}
  validate  :must_have_user
  include MiqProvisionQuotaMixin

  def vms
    Vm.find(options[:src_ids])
  end

  def self.make_request(request, values, requester, auto_approve = false)
    values[:request_type] = :vm_cloud_reconfigure

    ApplicationRecord.group_ids_by_region(values[:src_ids]).collect do |_region, ids|
      super(request, values.merge(:src_ids => ids), requester, auto_approve)
    end
  end

  def vm
    @vm ||= Vm.find_by(:id => options[:src_ids])
  end

  def my_zone
    vm.nil? ? super : vm.my_zone
  end

  def my_role(_action = nil)
    'ems_operations'
  end

  def my_queue_name
    vm.nil? ? super : vm.queue_name_for_ems_operations
  end
end
