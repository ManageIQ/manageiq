class Service < ActiveRecord::Base
  DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS = 120

  belongs_to :service_template               # Template this service was cloned from
  belongs_to :service                        # Parent Service
  has_many :services, :dependent => :destroy # Child services
  has_many :ems_events

  virtual_belongs_to :parent_service
  virtual_has_many   :direct_service_children
  virtual_has_many   :all_service_children
  virtual_has_many   :vms
  virtual_has_many   :all_vms
  virtual_column     :v_total_vms,            :type => :integer,  :uses => :vms

  include ServiceMixin
  include OwnershipMixin
  include CustomAttributeMixin

  include_concern 'RetirementManagement'
  include_concern 'Aggregation'

  virtual_column :has_parent,                               :type => :boolean

  validates_presence_of :name

  def add_resource(rsc, options={})
    raise MiqException::Error, "Vm <#{rsc.name}> is already connected to a service." if rsc.kind_of?(Vm) && !rsc.service.nil?
    super
  end
  alias << add_resource

  def parent_service
    self.service
  end

  def has_parent?
    self.service_id ? true : false
  end
  alias has_parent has_parent?

  def request_class
    ServiceReconfigureRequest
  end

  def request_type
    'service_reconfigure'
  end

  def root_service
    result = self
    until result.parent_service.nil?
      result = result.parent_service
    end
    result
  end

  def direct_service_children
    self.services
  end

  def indirect_service_children
    self.direct_service_children.collect { |s| s.direct_service_children + s.indirect_service_children }.flatten.compact
  end

  def all_service_children
    self.direct_service_children + self.indirect_service_children
  end

  def indirect_vms
    self.all_service_children.collect { |s| s.direct_vms }.flatten.compact
  end

  def direct_vms
    self.service_resources.collect { |sr| sr.resource.kind_of?(VmOrTemplate) ? sr.resource : nil }.flatten.compact
  end

  def all_vms
    self.direct_vms + self.indirect_vms
  end
  alias :vms :all_vms

  # Processes tasks received from the UI and queues them
  def self.process_tasks(options)
    raise "No ids given to process_tasks" if options[:ids].blank?
    raise "Unknown task, #{options[:task]}" unless self.instance_methods.collect { |m| m.to_s }.include?(options[:task])
    options[:userid] ||= "system"
    self.invoke_tasks_queue(options)
  end

  def self.invoke_tasks_queue(options)
    MiqQueue.put(:class_name => self.name, :method_name => "invoke_tasks", :args => [options])
  end

  # Performs tasks received from the UI via the queue
  def self.invoke_tasks(options)
    local, remote = self.partition_ids_by_remote_region(options[:ids])
    self.invoke_tasks_local(options.merge(:ids => local)) unless local.empty?
  end

  def self.invoke_tasks_local(options)
    options[:invoke_by] = :task
    args = []

    services, tasks = self.validate_tasks(options)

    audit = {:event => options[:task], :target_class => self.name, :userid => options[:userid]}

    services.each_with_index do |service, idx|
      task = MiqTask.find_by_id(tasks[idx])

      if task && task.status == "Error"
        AuditEvent.failure(audit.merge(:target_id => service.id, :message => task.message))
        task.state_finished
        next
      end

      cb = { :class_name => task.class.to_s, :instance_id => task.id, :method_name => :queue_callback, :args => ["Finished"] } if task

      MiqQueue.put(:class_name => self.name, :instance_id => service.id, :method_name => options[:task], :args => args, :miq_callback => cb)
      AuditEvent.success(audit.merge(:target_id => service.id, :message => "#{service.name}: '#{options[:task]}' successfully initiated"))
      task.update_status("Queued", "Ok", "Task has been queued") if task
    end
  end

  # Helper method for invoke_tasks, to determine the services and the tasks associated
  def self.validate_tasks(options)
    tasks = []

    services = self.find_all_by_id(options[:ids], :order => "lower(name)")
    return services, tasks unless options[:invoke_by] == :task # jobs will be used instead of tasks for feedback

    services.each do |service|
      # create a task instance for each VM
      task = MiqTask.create(:name => "#{service.name}: '" + options[:task] + "'", :userid => options[:userid])
      tasks.push(task.id)

      if options[:task] == "retire_now" && service.retired?
        task.error("#{service.name}: Service is already retired")
        next
      end
    end
    return services, tasks
  end

  def start
    self.raise_request_start_event
    queue_group_action(:start)
  end

  def stop
    self.raise_request_stop_event
    queue_group_action(:stop, self.last_group_index, -1)
  end

  def suspend
    queue_group_action(:suspend, self.last_group_index, -1)
  end

  def shutdown_guest
    queue_group_action(:shutdown_guest, self.last_group_index, -1)
  end

  def process_group_action(action, group_idx, direction)
    log_header = "MIQ(#{self.class.name}#process_group_action)"
    self.each_group_resource(group_idx) do |svc_rsc|
      begin
        rsc = svc_rsc.resource
        rsc_name =  "#{rsc.class.name}:#{rsc.id}" + (rsc.respond_to?(:name) ? ":#{rsc.name}" : "")
        if rsc.respond_to?(action)
          $log.info "#{log_header} Processing action <#{action}> for Service:<#{self.name}:#{self.id}>, RSC:<#{rsc_name}}> in Group Idx:<#{group_idx}>"
          rsc.send(action)
        else
          $log.info "#{log_header} Skipping action <#{action}> for Service:<#{self.name}:#{self.id}>, RSC:<#{rsc.class.name}:#{rsc.id}> in Group Idx:<#{group_idx}>"
        end
      rescue => err
        $log.error "Error while processing Service:<#{self.name}> Group Idx:<#{group_idx}>  Resource<#{rsc_name}>.  Message:<#{err}>"
      end
    end

    # Setup processing for the next group
    next_grp_idx = next_group_index(group_idx, direction)
    if next_grp_idx.nil?
      raise_final_process_event(action)
    else
      queue_group_action(action, next_grp_idx, direction, self.delay_for_action(next_grp_idx, action))
    end
  end

  def queue_group_action(action, group_idx=0, direction=1, deliver_delay=0)

    # Verify that the VMs attached to this service have not been converted to templates
    self.validate_resources

    nh = {
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => "process_group_action",
      :role        => "ems_operations",
      :task_id     => "#{self.class.name.underscore}_#{self.id}",
      :args        => [action, group_idx, direction]
    }
    nh[:deliver_on] = deliver_delay.seconds.from_now.utc if deliver_delay > 0
    first_vm = self.vms.first
    nh[:zone] = first_vm.ext_management_system.zone.name unless first_vm.nil?
    MiqQueue.put(nh)
    true
  end

  def validate_resources
    # self.each_group_resource do |svc_rsc|
    #   rsc = svc_rsc.resource
    #   raise "Unsupported resource type #{rsc.class.name}" if rsc.kind_of?(VmOrTemplate) && rsc.template? == true
    # end
  end

  def picture
    st = self.service_template
    return nil if st.nil?
    st.picture
  end

  def raise_final_process_event(action)
    case action.to_s
    when "start" then raise_started_event
    when "stop"  then raise_stopped_event
    end
  end

  def raise_request_start_event
    self.raise_event(:request_service_start, "Request Service #{self.name} start")
  end

  def raise_started_event
    self.raise_event(:service_started, "Service #{self.name} started")
  end

  def raise_request_stop_event
    self.raise_event(:request_service_stop, "Request Service #{self.name} stop")
  end

  def raise_stopped_event
    self.raise_event(:service_stopped, "Service #{self.name} stopped")
  end

  def raise_provisioned_event
    event = self.ems_events.where(:event_type => "service_provisioned")
    return event.first unless event.blank?
    self.raise_event(:service_provisioned, "Service #{self.name} provisioned")
  end

  def raise_event(event_type, message)
    EmsEvent.add(nil, {:service_id => self.id, :event_type => event_type, :timestamp => Time.now, :message => message})
  end

  def v_total_vms
    vms.size
  end
end
