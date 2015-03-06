class KubernetesEventMonitor
  def initialize(api_endpoint, api_version)
    @api_endpoint = api_endpoint
    @api_version = api_version
  end

  def inventory
    require 'kubeclient'
    @inventory ||= Kubeclient::Client.new(@api_endpoint, @api_version)
  end

  def watcher(version = nil)
    @watcher ||= inventory.watch_events(version)
  end

  def start
    trap(:TERM) { $kube_log.info('EventMonitor#start: ignoring SIGTERM') }
    @inventory = nil
    @watcher = nil
  end

  def stop
    watcher.finish
  end

  def each
    # At the moment we don't persist the last resourceVersion seen by the
    # inventory, this means that for now we take the last version and we
    # request events starting from there. This assumes that on reconnection
    # we should trigger a full inventory poll.
    # TODO: persist resourceVersion and gather only the relevant events
    # that may have been missed.
    version = inventory.get_events.resourceVersion
    watcher(version).each do |notice|
      yield notice
    end
  rescue EOFError => err
    $kube_log.info("Monitoring connection closed #{err}")
  end
end
