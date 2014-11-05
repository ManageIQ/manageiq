require 'workers/worker_base'
require 'thread'

require 'MiqVimControlMonitor'

class ControlMonitor < WorkerBase
  CONFIG_DEFAULTS = WorkerBase::CONFIG_DEFAULTS.merge(
    :poll => 10,
    :page => 100
  )

  OPTIONS_PARSER_SETTINGS = WorkerBase::OPTIONS_PARSER_SETTINGS + [
    [:ems_id, 'EMS Instance ID',     String],
    [:page,   'EMS Event Page size', Integer]
  ]

  def after_initialize
    $log.info("#{log_prefix}")

    @ems = ExtManagementSystem.find_by_id(@cfg[:ems_id])
  end

  def do_before_work_loop
    @tid = start_control_monitor
  end

  def log_prefix
    @log_prefix ||= "MIQ(#{self.class.name}) " #EMS [#{@ems.ipaddress}] as [#{@ems.authentication_userid}] "
  end

  alias old_do_exit do_exit
  def do_exit(message=nil, exit_code=0)
    drain_queue
  ensure
    old_do_exit(message, exit_code)
  end

  def start_control_monitor
    begin
      $log.info("#{self.log_prefix}Validating Connection/Credentials")
      @ems.ems_connections.find_by_provider_component("refresh").verify_credentials #COME BACK TO
    rescue => err
      $log.warn("#{self.log_prefix}#{err.message}")
      return nil
    end

    $log.info("#{self.log_prefix}Starting control monitor thread...")

    STDOUT.sync = true
    tid = Thread.new do
      begin
        vim_cm = MiqVimControlMonitor.new(@ems.ipaddress, @ems.authentication_userid, @ems.authentication_password, @cfg[:page])
        vim_cm.controlMonitor do |action|
          #$log.info "#{self.log_prefix}XXX: action: #{action.inspect}"
          #$log.info "#{self.log_prefix}XXX: action: methods: #{action.methods.sort.join("\n")}"
          #$log.info "#{self.log_prefix}XXX: action: vmName: #{action.vmName}"
          $log.info "#{self.log_prefix}Action [#{action.action}] received for VM [#{action.vmPath}]"

          begin
            storage_id, location = Vm.parse_path(action.vmPath)
            vm = Vm.find_by_storage_id_and_location(storage_id, location)
          rescue => err
            $log.error("#{self.log_prefix}#{err.message}")
            $log.log_backtrace(err)
          else
            inputs = {:vm => vm, :ext_management_system => @ems}
            event = "vm_start"
            $log.info "#{self.log_prefix}Raising Policy Event [#{event}]"
            MiqEvent.raise_evm_event(vm, event, inputs)
          end
        end
      rescue => err
        $log.error("#{self.log_prefix}Thread aborted because [#{err.message}]")
        $log.log_backtrace err
        Thread.exit
      end
    end

    $log.info("#{self.log_prefix}Started control monitor thread")

    return tid
  end

  def do_work
    if @tid.nil? || !@tid.alive?
      $log.info("#{self.log_prefix}Control Monitor thread gone. Restarting...")
      @tid = start_control_monitor
    end
  end
end
