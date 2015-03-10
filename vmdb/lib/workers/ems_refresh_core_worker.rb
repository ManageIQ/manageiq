require 'workers/worker_base'
require 'thread'

$:.push("#{File.dirname(__FILE__)}/../../../lib/VMwareWebService")

class EmsRefreshCoreWorker < WorkerBase
  self.wait_for_worker_monitor = false

  OPTIONS_PARSER_SETTINGS = WorkerBase::OPTIONS_PARSER_SETTINGS + [
    [:ems_id, 'EMS Instance ID', String],
  ]

  def after_initialize
    @ems = ExtManagementSystem.find(@cfg[:ems_id])
    do_exit("Unable to find instance for EMS id [#{@cfg[:ems_id]}].", 1) if @ems.nil?
    do_exit("EMS id [#{@cfg[:ems_id]}] failed authentication check.", 1) unless @ems.authentication_check.first == :valid

    # Global Work Queue
    @queue = Queue.new
  end

  def do_before_work_loop
    @tid = start_updater
  end

  def log_prefix
    @log_prefix ||= "MIQ(#{self.class.name}) EMS [#{@ems.hostname}] as [#{@ems.authentication_userid}]"
  end

  def before_exit(message, exit_code)
    @exit_requested = true

    unless @vim.nil?
      safe_log("#{message} Stopping thread.")
      @vim.stop rescue nil
    end

    unless @tid.nil?
      safe_log("#{message} Waiting for thread to stop.")
      @tid.join(self.worker_settings[:thread_shutdown_timeout] || 10.seconds) rescue nil
    end

    if @queue
      safe_log("#{message} Draining queue.")
      drain_queue rescue nil
    end
  end

  def start_updater
    @log_prefix = nil
    @exit_requested = false

    begin
      $log.info("#{self.log_prefix} Validating Connection/Credentials")
      @ems.verify_credentials
    rescue => err
      $log.warn("#{self.log_prefix} #{err.message}")
      return nil
    end

    $log.info("#{self.log_prefix} Starting thread")
    require 'MiqVimCoreUpdater'

    tid = Thread.new do
      begin
        @vim = MiqVimCoreUpdater.new(@ems.hostname, @ems.authentication_userid, @ems.authentication_password)
        @vim.monitorUpdates { |*u| @queue.enq(u) }
      rescue Handsoap::Fault => err
        if ( @exit_requested && (err.code == "ServerFaultCode") && (err.reason == "The task was canceled by a user.") )
          $log.info("#{self.log_prefix} Thread terminated normally")
        else
          $log.error("#{self.log_prefix} Thread aborted because [#{err.message}]")
          $log.error("#{self.log_prefix} Error details: [#{err.details}]")
          $log.log_backtrace(err)
        end
        Thread.exit
      rescue => err
        $log.error("#{self.log_prefix} Thread aborted because [#{err.message}]")
        $log.log_backtrace(err) unless err.kind_of?(Errno::ECONNREFUSED)
        Thread.exit
      end
    end

    $log.info("#{self.log_prefix} Started thread")

    return tid
  end

  def do_work
    if @tid.nil? || !@tid.alive?
      $log.info("#{self.log_prefix} Thread gone. Restarting...")
      @tid = start_updater
    end

    process_updates
  end

  def drain_queue
    process_update(@queue.deq) while @queue.length > 0
  end

  def process_updates
    while @queue.length > 0
      heartbeat
      process_update(@queue.deq)
      Thread.pass
    end
  end

  def process_update(update)
    mor, props = update
    return if mor.vimType != "VirtualMachine" # Ignore non-VMs for now
    return if props.nil?                      # Ignore deleted/created VMs for now

    # HACK: MiqVimCoreUpdater needs to have this property added in order to
    #       deal with issues where VC4 will give periodic full updates unless
    #       there is a property that returns frequently.  We deal with this by
    #       ignoring it.  See FB15506.
    props.delete("runtime.memoryOverhead")
    return if props.empty?

    vm = VmOrTemplate.find_by_ems_ref_and_ems_id(mor, @ems.id)
    return if vm.nil?

    new_attrs = {}
    props.each do |k, v|
      case k
      when "runtime.powerState"
        new_attrs[:raw_power_state] = v
      when "config.template"
        new_attrs[:template] = (v.to_s.downcase == "true")
      when "guest.net"
        process_vm_guest_net(vm, v)
      end
    end

    # Don't set the raw_power_state directly for templates or templates-to-be
    new_attrs.delete(:raw_power_state) if new_attrs[:template] || (new_attrs[:template].nil? && vm.template?)

    unless new_attrs.blank?
      $log.info("#{self.log_prefix} Updating Vm id: [#{vm.id}], name: [#{vm.name}] with the following attributes: #{new_attrs.inspect}")
      vm.update_attributes(new_attrs)
    end
  end

  # NOTE: At this time, this method only handles updates to existing nics and
  #   will not create or delete nics.
  def process_vm_guest_net(vm, inv)
    inv = inv.to_miq_a
    return if inv.none? { |i| i['connected'] }

    MiqPreloader.preload(vm, :hardware => {:nics => :network})

    nics = vm.try(:hardware).try(:nics).to_miq_a.select(&:network)
    return if nics.blank?
    nics_by_uid = nics.index_by(&:address)

    new_attrs_by_nic_uid = {}

    inv.each do |i|
      uid = i['macAddress']
      next unless nics_by_uid.has_key?(uid)

      ipv4, ipv6 = i['ipAddress'].to_miq_a.compact.collect(&:to_s).partition(&:ipv4?)
      ipv4 = ipv4.first
      ipv6 = ipv6.first
      next if ipv4.nil? && ipv6.nil?

      new_attrs_by_nic_uid[uid] = {
        :ipaddress   => ipv4,
        :ipv6address => ipv6
      }
    end

    unless new_attrs_by_nic_uid.empty?
      $log.info("#{self.log_prefix} Updating Vm id: [#{vm.id}], name: [#{vm.name}] with the following network attributes: #{new_attrs_by_nic_uid.inspect}")
      new_attrs_by_nic_uid.each { |uid, new_attrs| nics_by_uid[uid].network.update_attributes(new_attrs) }
    end
  end
end
