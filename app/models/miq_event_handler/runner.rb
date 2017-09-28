class MiqEventHandler::Runner < MiqQueueWorkerBase::Runner
  def do_work
    # If we are using MiqQueue then use the default do_work method
    super unless worker_settings[:queue_type] == "artemis"

    require "manageiq-messaging"

    ManageIQ::Messaging.logger = _log

    connect_opts = {
      :host       => worker_settings[:queue_hostname],
      :port       => worker_settings[:queue_port].to_i,
      :username   => worker_settings[:queue_username],
      :password   => worker_settings[:queue_password],
      :client_ref => "event_handler",
    }

    ManageIQ::Messaging::Client.open(connect_opts) do |client|
      _log.info "Listening for events..."

      topic_opts = {
        :service     => "events",
        :persist_ref => "event_handler"
      }

      client.subscribe_topic(topic_opts) do |sender, event, payload|
        _log.info "Received Event (#{event}) by sender #{sender}: #{payload[:event_type]} #{payload[:chain_id]}"
        EmsEvent.add(sender.to_i, payload)
      end

      # never exit - the above block is stored as a callback and is executed by another thread
      loop do
        heartbeat
        sleep(worker_settings[:heartbeat_freq])
      end
    end
  end
end
