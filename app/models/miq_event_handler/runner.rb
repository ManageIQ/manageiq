class MiqEventHandler::Runner < MiqQueueWorkerBase::Runner
  def artemis?
    Settings.prototype.queue_type == 'artemis'
  end

  def do_before_work_loop
    if artemis?
      topic_options = {
        :service     => "events",
        :persist_ref => "event_handler"
      }

      # this block is stored in a lambda callback and is executed in another thread once a msg is received
      MiqQueue.artemis_client('event_handler').subscribe_topic(topic_options) do |sender, event, payload|
        _log.info "Received Event (#{event}) by sender #{sender}: #{payload[:event_type]} #{payload[:chain_id]}"
        EmsEvent.add(sender.to_i, payload)
      end
      _log.info "Listening for events..."
    end
  end

  def do_work
    # If we are using MiqQueue then use the default do_work method
    super unless artemis?

    # we dont do any work, we are lazy
    # upon msg received, the messaging thread will execute the block in .subscribe_topic as above
    # sleeping is done in do_work_loop
  end

  def before_exit(_message, _exit_code)
    return unless artemis?
    MiqQueue.artemis_client('event_handler').close
  rescue => e
    safe_log("Could not close artemis connection: #{e}", 1)
  end
end
