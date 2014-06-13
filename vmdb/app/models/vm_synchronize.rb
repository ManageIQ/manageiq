class VmSynchronize < Job
  state_machine :state, :initial => :initialize do
    event :initializing do
      transition :initialize => :waiting_to_start
    end

    event :start do
      transition :waiting_to_start => :synchronize
    end
    after_transition :on => :start, :waiting_to_start => :synchronize, :do => :call_synchronize

    event :sync_started do
      transition :synchronize => :synchronizing
    end

    event :data do
      transition :synchronizing => same
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

  def call_synchronize
    $log.info "action-call_synchronize: Enter"

    self.options[:categories] ||= Vm.default_scan_categories
    begin
      host = Host.find(self.agent_id)
      vm   = VmOrTemplate.find(self.target_id)
      vm.sync_metadata( self.options[:categories], "taskid" => jobid, "host" => host )
    rescue TimeoutError
      message = "timed out attempting to synchronize, aborting"
      $log.error("MIQ(vmsyncdata-action-call_synchronize) #{message}")
      signal(:abort, message, "error")
      return
    rescue => message
      $log.error("MIQ(vmsyncdata-action-call_synchronize) #{message}")
      signal(:abort, message.message, "error")
    end

    dispatch_finish # let the dispatcher know that it is ok to start the next job this way another job can run while we're processing the data.
    set_status("Synchronizing metadata from VM")
    signal(:sync_started)
  end

  def process_data(transition)
    $log.info "action-process_data: starting..."

    data = transition.args.first

    set_status("Processing VM data")

    doc = MiqXml.load(data)
    $log.info "action-process_data: Document=#{doc.root.name.downcase}"

    if doc.root.name.downcase == "summary"
      doc.root.each_element do |s|
        case s.name.downcase
        when "syncmetadata"
          request_docs = []
          all_docs = []
          s.each_element { |e|
            $log.info("action-process_data: Summary XML [#{e.to_s}]")
            request_docs << e.attributes['original_filename'] if e.attributes['items_total'] && e.attributes['items_total'].to_i.zero?
            all_docs << e.attributes['original_filename']
          }
          unless request_docs.empty? || (request_docs.length != all_docs.length)
            message = "synchronize operation yielded no data. aborting"
            $log.error("action-process_data: #{message}")
            signal(:abort, message, "error")
          else
            $log.info("action-process_data: sending :finish")
            signal(:finish, "Process completed successfully", "ok")
          end
        else
          $log.info("action-process_data: no action taken")
        end
      end
    end
    # got data to process
  end
end
