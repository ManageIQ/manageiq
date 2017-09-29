class MiqEventHandler::Runner < MiqQueueWorkerBase::Runner
  def artemis?
    worker_settings[:queue_type] == "artemis"
  end

  def artemis_client
    # FIXME: maybe we move that client to a global connection, like ActiveRecord
    # FIXME: logger should be set at a global level
    require "manageiq-messaging"
    ManageIQ::Messaging.logger = _log
    @artemis_client ||= begin
      connect_opts = {
        :host       => worker_settings[:queue_hostname],
        :port       => worker_settings[:queue_port].to_i,
        :username   => worker_settings[:queue_username],
        :password   => worker_settings[:queue_password],
        :client_ref => "event_handler",
      }

      ManageIQ::Messaging::Client.open(connect_opts)
    end
  end

  def do_before_work_loop
    if artemis?
      topic_options = {
        :service     => "events",
        :persist_ref => "event_handler"
      }

      # this block is stored in a lambda callback and is executed in another thread once a msg is received
      artemis_client.subscribe_topic(topic_options) do |sender, event, payload|
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

    # FIXME: what about these checks?
    # this checks cpu usage, iirc this is done in a worker monitor anyways
    # break if thresholds_exceeded?

    # is that some kind of setting?
    # break if message_delivery_suspended?
  end

  def before_exit(_message, _exit_code)
    artemis_client.close if artemis?
  end
end
