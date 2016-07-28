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
  ERRCODE_POD_NOTFOUND = 404
  IMAGE_INSPECTOR_SA = 'inspector-admin'
  INSPECTOR_ADMIN_SECRET_PATH = '/var/run/secrets/kubernetes.io/inspector-admin-secret-'

  def load_transitions
    self.state ||= 'initializing'
    {
      :initializing => {'initializing'     => 'waiting_to_start'},
      :start        => {'waiting_to_start' => 'pod_create'},
      :pod_wait     => {'pod_create'       => 'waiting_to_scan'},
      :analyze      => {'waiting_to_scan'  => 'scanning'},
      :data         => {'scanning'      => 'synchronizing',
                        'synchronizing' => 'synchronizing'},
      :cleanup      => {'synchronizing'    => 'pod_delete'},
      :abort_job    => {'*'                => 'aborting'},
      :finish       => {'pod_delete' => 'finished',
                        'aborting'   => 'finished'},
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

    pod = pod_definition
    _log.info("creating pod #{pod_full_name} to analyze docker image " \
              "#{options[:docker_image_id]}: #{pod.to_json}")

    begin
      kubernetes_client.create_pod(pod)
    rescue SocketError, KubeException => e
      msg = "pod creation for #{pod_full_name} failed: #{e}"
      _log.info(msg)
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
    loop do
      response = pod_health_poll(client, health_url, http_options)

      case response
      when Net::HTTPOK
        _log.info("pod #{pod_full_name} is ready and accessible")
        break
      when Net::HTTPServiceUnavailable
        # TODO: check that the pod wasn't terminated (exit code)
        # continue: pod is still not up and running
      else
        msg = "unknown access error to pod #{pod_full_name}: #{response}"
        _log.info(msg)
        return queue_signal(:abort_job, msg, "error")
      end

      # TODO: for recovery purposes it would be better if this
      # method was short-lived instead of waiting for the pod to be
      # available
      _log.info("pod #{pod_full_name} is not available")
      sleep(POD_POLL_INTERVAL)
    end

    queue_signal(:analyze)
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

    actual = image_inspector_client.fetch_metadata.Id
    if actual != options[:docker_image_id]
      msg = "cannot analyze image %s with id %s: detected id was %s"
      _log.error(msg % [options[:image_full_name], options[:docker_image_id], actual])
      return queue_signal(:abort_job,
                          msg % [options[:image_full_name], options[:docker_image_id][0..11], actual[0..11]],
                          'error')
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

  def cleanup(*args)
    image = target_entity
    if image
      # TODO: check job success / failure
      MiqEvent.raise_evm_job_event(image, :type => "scan", :suffix => "complete")
    end
    client = kubernetes_client

    begin
      pod = client.get_pod(options[:pod_name], options[:pod_namespace])
    rescue KubeException => e
      if e.error_code == ERRCODE_POD_NOTFOUND
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
    set_status('image analysis completed successfully', 'ok')

  ensure
    args.empty? ? queue_signal(:finish) : process_abort(*args)
  end

  def finish(*_args)
    # exactly like job.dispatch_finish except for storage bits
    _log.info "Dispatch Status is 'finished'"
    update(:dispatch_status => "finished")
  end

  alias_method :abort_job, :cleanup

  def queue_callback(state, msg, _)
    if state == "timeout" && self.state != "aborting"
      queue_signal(:abort_job, "Job Timeout: #{msg}", "error")
    end
  end

  private

  def target_entity
    target_class.constantize.find_by_id(target_id)
  end

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
      :ssl_options  => kubeclient.ssl_options,
      :auth_options => kubeclient.auth_options
    )
  end

  def queue_signal(*args)
    MiqQueue.put_unless_exists(
      :args        => args,
      :class_name  => "Job",
      :instance_id => id,
      :method_name => "signal",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => "smartstate",
      :task_id     => guid,
      :zone        => zone
    ) do |_msg, find_options|
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
      raise e unless e.error_code == 404
      _log.warn("Service Account #{IMAGE_INSPECTOR_SA} does not exist.")
    end
    return nil
  end

  def pod_definition
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
            ]
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

    inspector_admin_secret_name = inspector_admin_secret
    add_secret_to_pod_def(pod_def, inspector_admin_secret_name) unless inspector_admin_secret_name.blank?

    Kubeclient::Pod.new(pod_def)
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
    'docker.io/openshift/image-inspector:2.0'
  end
end
