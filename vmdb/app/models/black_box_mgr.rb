class BlackBoxMgr < Job
  def load_transitions
    self.state ||= 'initialize'
    {
      :initializing => {'initialize'             => 'waiting_to_start'      },
      :start        => {'waiting_to_start'       => 'preprocess_remote_task'},
      :data         => {'preprocess_remote_task' => 'process_data'          },
      :abort_job    => {'*'                      => 'aborting'              },
      :cancel       => {'*'                      => 'canceling'             },
      :finish       => {'*'                      => 'finished'              },
      :error        => {'*'                      => '*'                     }
    }
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

  def process_data(*args)
    $log.info "action-call_process_data: Enter"
    xmlFile = args.first
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

  # Map signals
  alias_method :start,     :call_preprocess_remote_task
  alias_method :data,      :process_data
  alias_method :abort_job, :process_abort
  alias_method :cancel,    :process_cancel
  alias_method :finish,    :process_finished
  alias_method :error,     :process_error
end
