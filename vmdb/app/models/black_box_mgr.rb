class BlackBoxMgr < Job

  state_machine :state, :initial => :initialize do
    event :initializing do
      transition :initialize => :waiting_to_start
    end

    event :start do
      transition :waiting_to_start => :preprocess_remote_task
    end
    after_transition :on => :start, :waiting_to_start => :preprocess_remote_task, :do => :call_preprocess_remote_task

    event :data do
      transition :preprocess_remote_task => :process_data
    end
    after_transition :on => :data, :do => :process_data

    event :abort_job do
      transition all => :aborting
    end

    event :cancel do
      transition all => :canceling
    end

    event :finish do
      transition all => :finished
    end

    event :error do
      transition all => same
    end
    # On the Error event, call the error method
    after_transition :on => :error,     :do => :process_error

    # On Entry to the State
    after_transition all => :aborting,  :do => :process_abort
    after_transition all => :canceling, :do => :process_cancel
    after_transition all => :finished,  :do => :process_finished
  end

  def call_preprocess_remote_task
    $log.info "action-call_preprocess_remote_task: Enter"

    begin
      host = Host.find(self.agent_id)
      vm   = VmOrTemplate.find(self.target_id)

      ws_options = {"taskid" => jobid, "host" => host}

      # Determine what remote method to call based on the current mode
      case self.options[:mode]
      when "validate"
        set_status("Validating Blackbox")
        ws_options[:ws_method] = "ValidateBlackBox"
      when "create"
        set_status("Creating Blackbox")
        ws_options[:ws_method] = "CreateBlackBox"
      when "delete"
        set_status("Deleting Blackbox")
        ws_options[:ws_method] = "DeleteBlackBox"
      else
        raise "Blackbox Manager mode [#{self.options[:mode]}] unknown"
      end

      vm.blackbox_manager_ws(ws_options)

    rescue TimeoutError
      message = "timed out, attempting to scan, aborting"
      $log.error("MIQ(scan-preprocess_remote_task) #{message}")
      signal(:abort, message, "error")
      return
    rescue => err
      $log.warn "Blackbox Manager error: [#{err}]"
      signal(:abort, err.to_s, "error")
    end
  end

  def process_data(transition)
    $log.info "action-call_process_data: Enter"
    xmlFile = transition.args.first
    # Add code here to call WS to attachdisk
    set_status("Processing data")
    vm = VmOrTemplate.find(self.options[:target_id])
    begin
      doc = MiqXml.load(xmlFile)
      doc.root.each_element do |xmlNode|
        case xmlNode.name.downcase
        when "validateblackbox", "createblackbox", "deleteblackbox"
          vm.process_blackbox_summary(xmlNode, self.jobid)
        end
      end

      signal(:finish, "Process completed successfully", "ok")
    rescue => err
      $log.warn "Blackbox Manager error: [#{err}]"
      signal(:abort, err.to_s, "error")
    end
  end
end
