class MiqUiWorker < MiqWorker
  self.required_roles = ['terraform_runner']

  STARTING_PORT = 6000

  def friendly_name
    @friendly_name ||= "Terraform Runner Worker"
  end

  include MiqWebServerWorkerMixin
  include MiqWorker::ServiceWorker

  def self.bundler_groups
    %w[manageiq_default terraform_runner_dependencies]
  end

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_TERRAFORM_RUNNER_WORKERS
  end

  def container_port
    6001
  end

  def container_image_name
    "terraform-runner-worker"
  end

  def container_image
    ENV["TERRAFORM_RUNNER_WORKER_IMAGE"] || default_image
  end

end
