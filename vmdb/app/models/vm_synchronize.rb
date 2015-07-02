class VmSynchronize < Job
  def load_transitions
    self.state ||= 'initialize'
    {
      :initializing => {'initialize'       => 'waiting_to_start'},
      :start        => {'waiting_to_start' => 'synchronize'     },
      :sync_started => {'synchronize'      => 'synchronizing'   },
      :data         => {'synchronizing'    => 'synchronizing'   },
      :abort_job    => {'*'                => 'aborting'        },
      :cancel       => {'*'                => 'canceling'       },
      :finish       => {'*'                => 'finished'        },
      :error        => {'*'                => '*'               }
    }
  end

  def call_synchronize
    _log.info "Enter"

    self.options[:categories] ||= Vm.default_scan_categories
    begin
      host = Host.find(self.agent_id)
      vm   = VmOrTemplate.find(self.target_id)
      vm.sync_metadata( self.options[:categories], "taskid" => jobid, "host" => host )
    rescue TimeoutError
      message = "timed out attempting to synchronize, aborting"
      _log.error("#{message}")
      signal(:abort, message, "error")
      return
    rescue => message
      _log.error("#{message}")
      signal(:abort, message.message, "error")
    end

    dispatch_finish # let the dispatcher know that it is ok to start the next job this way another job can run while we're processing the data.
    set_status("Synchronizing metadata from VM")
    signal(:sync_started)
  end

  def process_data(*args)
    _log.info "starting..."

    data = args.first

    set_status("Processing VM data")

    doc = MiqXml.load(data)
    _log.info "Document=#{doc.root.name.downcase}"

    if doc.root.name.downcase == "summary"
      doc.root.each_element do |s|
        case s.name.downcase
        when "syncmetadata"
          request_docs = []
          all_docs = []
          s.each_element { |e|
            _log.info("Summary XML [#{e}]")
            request_docs << e.attributes['original_filename'] if e.attributes['items_total'] && e.attributes['items_total'].to_i.zero?
            all_docs << e.attributes['original_filename']
          }
          unless request_docs.empty? || (request_docs.length != all_docs.length)
            message = "synchronize operation yielded no data. aborting"
            _log.error("#{message}")
            signal(:abort, message, "error")
          else
            _log.info("sending :finish")
            signal(:finish, "Process completed successfully", "ok")
          end
        else
          _log.info("no action taken")
        end
      end
    end
    # got data to process
  end

  # Map signals
  alias_method :start,     :call_synchronize
  alias_method :data,      :process_data
  alias_method :abort_job, :process_abort
  alias_method :cancel,    :process_cancel
  alias_method :finish,    :process_finished
  alias_method :error,     :process_error
end
