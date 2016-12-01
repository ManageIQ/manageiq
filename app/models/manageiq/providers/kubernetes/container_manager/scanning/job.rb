require 'image-inspector-client'
require 'kubeclient'

class ManageIQ::Providers::Kubernetes::ContainerManager::Scanning::Job < Job
  PROVIDER_CLASS = ManageIQ::Providers::Kubernetes::ContainerManager
  INSPECTOR_NAMESPACE_FALLBACK = 'management-infra'
  INSPECTOR_PORT = 8080
  DOCKER_SOCKET = '/var/run/docker.sock'
  SCAN_CATEGORIES = %w(system software)
  POD_POLL_INTERVAL = 10
  IMAGES_GUEST_OS = 'Linux'
  INSPECTOR_HEALTH_PATH = '/healthz'
  ERRCODE_NOTFOUND = 404
  IMAGE_INSPECTOR_SA = 'inspector-admin'
  INSPECTOR_ADMIN_SECRET_PATH = '/var/run/secrets/kubernetes.io/inspector-admin-secret-'
  ATTRIBUTE_SECTION = 'cluster_settings'
  PROXY_ENV_VARIABLES = %w(no_proxy http_proxy https_proxy)

  def load_transitions
    self.state ||= 'initializing'
    {
      :initializing => {'initializing'     => 'waiting_to_start'},
      :start        => {'waiting_to_start' => 'pod_create'},
      :pod_wait     => {'pod_create'       => 'waiting_to_scan',
                        'waiting_to_scan'  => 'waiting_to_scan'},
      :analyze      => {'waiting_to_scan'  => 'scanning'},
      :data         => {'scanning'      => 'synchronizing',
                        'synchronizing' => 'synchronizing'},
      :cleanup      => {'synchronizing'    => 'pod_delete'},
      :abort_job    => {'*'                => 'aborting'},
      :cancel_job   => {'*'                => 'canceling'},
      :cancel       => {'*'                => 'canceling'},
      :finish       => {'pod_delete' => 'finished',
                        'aborting'   => 'finished',
                        'canceling'  => 'finished'},
    }
  end

  def initializing
    # exactly like job.dispatch_start except for storage bits
    _log.info "Dispatch Status is 'pending'"
    update(:dispatch_status => "pending")
  end

  def start
    image = target_entity
    return queue_signal(:abort_job, "no image found", "error") unless image
    return queue_signal(:abort_job, "cannot analyze non docker images", "error") unless image.docker_id

    ems_configs = VMDB::Config.new('vmdb').config[:ems]

    namespace = ems_configs.fetch_path(:ems_kubernetes, :miq_namespace)
    namespace = INSPECTOR_NAMESPACE_FALLBACK if namespace.blank?

    update!(:options => options.merge(
      :docker_image_id => image.docker_id,
      :image_full_name => image.full_name,
      :pod_name        => "manageiq-img-scan-#{guid[0..4]}",
      :pod_port        => INSPECTOR_PORT,
      :pod_namespace   => namespace
    ))

    _log.info("Getting inspector-admin secret for pod [#{pod_full_name}]")
    begin
      inspector_admin_secret_name = inspector_admin_secret
    rescue SocketError, KubeException => e
      msg = "getting inspector-admin secret failed"
      _log.error("#{msg}: [#{e}]")
      return queue_signal(:abort_job, msg, "error")
    end

    pod = pod_definition(inspector_admin_secret_name)

    _log.info("Creating pod [#{pod_full_name}] to analyze docker image [#{options[:docker_image_id]}] [#{pod.to_json}]")
    begin
      kubernetes_client.create_pod(pod)
    rescue SocketError, KubeException => e
      msg = "pod creation for [#{pod_full_name}] failed"
      _log.error("#{msg}: [#{e}]")
      return queue_signal(:abort_job, msg, "error")
    end

    queue_signal(:pod_wait)
  end

  def pod_wait
    _log.info("waiting for pod #{pod_full_name} to be available")

    client       = kubernetes_client
    health_url   = pod_proxy_url(client, INSPECTOR_HEALTH_PATH)
    http_options = {
      :use_ssl     => health_url.scheme == 'https',
      :verify_mode => ext_management_system.verify_ssl_mode
    }

    # TODO: move this to a more appropriate place (lib)
    response = pod_health_poll(client, health_url, http_options)

    case response
    when Net::HTTPOK
      _log.info("pod #{pod_full_name} is ready and accessible")
      queue_signal(:analyze)
    when Net::HTTPServiceUnavailable
      # TODO: check that the pod wasn't terminated (exit code)
      # continue: pod is still not up and running
      _log.info("pod #{pod_full_name} is not available")
      queue_signal(:pod_wait,
                   :deliver_on => POD_POLL_INTERVAL.seconds.from_now.utc)
    else
      msg = "unknown access error to pod #{pod_full_name}: #{response}"
      _log.info(msg)
      queue_signal(:abort_job, msg, "error")
    end
  end

  def verify_scanned_image_id
    metadata = image_inspector_client.fetch_metadata
    actual = metadata.Id
    return nil if actual == options[:docker_image_id]
    msg = "cannot analyze image %s with id %s: detected ids were %s" % [
      options[:image_full_name], options[:docker_image_id][0..11], actual[0..11]]

    if metadata.RepoDigests
      metadata.RepoDigests.each do |repo_digest|
        return nil if repo_digest == options[:docker_image_id]
        msg << repo_digest.split('@')[0..11] + ", "
      end
    end

    msg
  end

  def analyze
    image = target_entity
    return queue_signal(:abort_job, "no image found", "error") unless image

    _log.info("scanning image #{options[:docker_image_id]}")

    scan_args = {
      :pod_namespace => options[:pod_namespace],
      :pod_name      => options[:pod_name],
      :pod_port      => options[:pod_port],
      :guest_os      => IMAGES_GUEST_OS
    }

    verify_error = verify_scanned_image_id
    if verify_error
      _log.error(verify_error)
      return queue_signal(:abort_job, verify_error, 'error')
    end

    collect_compliance_data(image)

    image.scan_metadata(SCAN_CATEGORIES,
                        "taskid" => jobid,
                        "host"   => MiqServer.my_server,
                        "args"   => [YAML.dump(scan_args)])
  end

  def collect_compliance_data(image)
    _log.info "collecting compliance data for #{options[:docker_image_id]}"
    openscap_result = image.openscap_result || OpenscapResult.new(:container_image => image)
    openscap_result.attach_raw_result(image_inspector_client.fetch_oscap_arf)
    openscap_result.save
  rescue ImageInspectorClient::InspectorClientException => e
    _log.error("collecting compliance data for #{options[:docker_image_id]} with error: #{e}")
  end

  def synchronize
    image = target_entity
    return queue_signal(:abort_job, "no image found", "error") unless image

    image.sync_metadata(SCAN_CATEGORIES,
                        "taskid" => jobid,
                        "host"   => MiqServer.my_server)
  end

  def data(payload)
    payload_document = MiqXml.load(payload)

    if payload_document.root.name.downcase == "summary"
      case operation = payload_document.root.first.name.downcase
      when "scanmetadata" then synchronize
      when "syncmetadata" then queue_signal(:cleanup)
      else raise "Unknown operation #{operation}"
      end
    end
  end

  def delete_pod
    return if options[:pod_name].blank?
    client = kubernetes_client

    begin
      pod = client.get_pod(options[:pod_name], options[:pod_namespace])
    rescue KubeException => e
      if e.error_code == ERRCODE_NOTFOUND
        _log.info("pod #{pod_full_name} not found, skipping delete")
        return
      end
      # TODO: handle the cleanup at a later time
      raise
    end

    pod_jobid = pod.metadata.annotations['manageiq.org/jobid']

    # If the job id is not matching the pod was not created by this
    # job and ManageIQ instance.
    if pod_jobid != jobid
      _log.info("skipping delete for pod #{pod_full_name} with " \
                "job id #{pod_jobid}")
    else
      _log.info("deleting pod #{pod_full_name}")
      begin
        client.delete_pod(options[:pod_name], options[:pod_namespace])
      rescue SocketError, KubeException => e
        _log.info("pod #{pod_full_name} deletion failed: #{e}")
        # TODO: handle the cleanup at a later time
      end
    end
  end

  def cleanup(*args)
    image = target_entity
    if image
      # TODO: check job success / failure
      MiqEvent.raise_evm_job_event(image, :type => "scan", :suffix => "complete")
    end

    delete_pod

  ensure
    case self.state
    when 'aborting' then process_abort(*args)
    when 'canceling' then process_cancel(*args)
    else queue_signal(:finish, 'image analysis completed successfully', 'ok')
    end
  end

  def finish(*args)
    # exactly like job.dispatch_finish except for storage bits
    _log.info "Dispatch Status is 'finished'"
    update(:dispatch_status => "finished")
    process_finished(*args)
  end

  alias_method :abort_job, :cleanup

  def cancel(*_args)
    _log.info "Job Canceling"
    if self.state != "canceling" # ensure change of states
      signal :cancel
    else
      unqueue_all_signals
      queue_signal(:cancel_job)
    end
  end
  alias_method :cancel_job, :cleanup

  def queue_callback(state, msg, _)
    if state == "timeout" && self.state != "aborting"
      queue_signal(:abort_job, "Job Timeout: #{msg}", "error")
    end
  end

  private

  def ext_management_system
    @ext_management_system ||= ExtManagementSystem.find(options[:ems_id])
  end

  def kubernetes_client
    ext_management_system.connect(:service => PROVIDER_CLASS.ems_type)
  end

  def image_inspector_client
    kubeclient = kubernetes_client

    ImageInspectorClient::Client.new(
      pod_proxy_url(kubeclient, ''),
      'v1',
      :ssl_options    => kubeclient.ssl_options,
      :auth_options   => kubeclient.auth_options,
      :http_proxy_uri => kubeclient.http_proxy_uri
    )
  end

  def queue_options
    {
      :class_name  => "Job",
      :instance_id => id,
      :method_name => "signal",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => "smartstate",
      :task_id     => guid,
      :zone        => zone
    }
  end

  def unqueue_all_signals
    MiqQueue.unqueue(queue_options)
  end

  def queue_signal(*args, deliver_on: nil)
    MiqQueue.put_unless_exists(**queue_options, :args => args, :deliver_on => deliver_on) do |_msg, find_options|
      find_options.merge(
        :miq_callback => {
          :class_name  => self.class.to_s,
          :instance_id => id,
          :method_name => :queue_callback
        }
      )
    end
  end

  def pod_health_poll(client, health_url, http_opts)
    Net::HTTP.start(health_url.host, health_url.port, http_opts) do |http|
      request = Net::HTTP::Get.new(health_url.path)
      client.headers.each { |k, v| request[k.to_s] = v }
      return http.request(request)
    end
  end

  def pod_proxy_url(client, path = "")
    # TODO: change proxy_url in kubeclient to return URI
    pod_proxy = client.proxy_url(:pod,
                                 options[:pod_name],
                                 options[:pod_port],
                                 options[:pod_namespace])
    URI.parse(pod_proxy + path)
  end

  def pod_full_name
    "#{options[:pod_namespace]}/#{options[:pod_name]}"
  end

  def inspector_admin_secret
    kubeclient = kubernetes_client
    begin
      inspector_sa = kubeclient.get_service_account(IMAGE_INSPECTOR_SA, options[:pod_namespace])
      # TODO: support multiple imagePullSecrets. This depends on image-inspector support
      return inspector_sa.try(:imagePullSecrets).to_a[0].try(:name)
    rescue KubeException => e
      raise e unless e.error_code == ERRCODE_NOTFOUND
      _log.warn("Service Account #{IMAGE_INSPECTOR_SA} does not exist.")
    end
    return nil
  end

  def pod_definition(inspector_admin_secret_name)
    pod_def = {
      :apiVersion => "v1",
      :kind       => "Pod",
      :metadata   => {
        :name        => options[:pod_name],
        :namespace   => options[:pod_namespace],
        :labels      => {
          'name'         => options[:pod_name],
          'manageiq.org' => "true"
        },
        :annotations => {
          'manageiq.org/hostname' => options[:miq_server_host],
          'manageiq.org/guid'     => options[:miq_server_guid],
          'manageiq.org/image'    => options[:image_full_name],
          'manageiq.org/jobid'    => jobid,
        }
      },
      :spec       => {
        :restartPolicy => 'Never',
        :containers    => [
          {
            :name            => "image-inspector",
            :image           => inspector_image,
            :imagePullPolicy => "Always",
            :command         => [
              "/usr/bin/image-inspector",
              "--chroot",
              "--image=#{options[:image_full_name]}",
              "--scan-type=openscap",
              "--serve=0.0.0.0:#{options[:pod_port]}"
            ],
            :ports           => [{:containerPort => options[:pod_port]}],
            :securityContext => {:privileged =>  true},
            :volumeMounts    => [
              {
                :mountPath => DOCKER_SOCKET,
                :name      => "docker-socket"
              }
            ],
            :env             => inspector_proxy_env_variables
          }
        ],
        :volumes       => [
          {
            :name     => "docker-socket",
            :hostPath => {:path => DOCKER_SOCKET}
          }
        ]
      }
    }

    add_secret_to_pod_def(pod_def, inspector_admin_secret_name) unless inspector_admin_secret_name.blank?
    Kubeclient::Resource.new(pod_def)
  end

  def add_secret_to_pod_def(pod_def, inspector_admin_secret_name)
    pod_def[:spec][:containers][0][:command].append("--dockercfg=" + INSPECTOR_ADMIN_SECRET_PATH +
                                                    inspector_admin_secret_name + "/.dockercfg")
    pod_def[:spec][:containers][0][:volumeMounts].append(
      :name      => "inspector-admin-secret",
      :mountPath => INSPECTOR_ADMIN_SECRET_PATH + inspector_admin_secret_name,
      :readOnly  => true)
    pod_def[:spec][:volumes].append(
      :name   => "inspector-admin-secret",
      :secret => {:secretName => inspector_admin_secret_name})
  end

  def inspector_image
    'docker.io/openshift/image-inspector:2.1'
  end

  def inspector_proxy_env_variables
    settings = ext_management_system.custom_attributes
    settings.where(:section => ATTRIBUTE_SECTION,
                   :name    => PROXY_ENV_VARIABLES).each_with_object([]) do |att, env|
      env << {:name  => att.name.upcase,
              :value => att.value} unless att.value.blank?
    end
  end
end
