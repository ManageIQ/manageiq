class ServiceContainer < Service
  include ServiceContainerMixin

  # The live status of the deployment from provider
  def deployment_status
    # TODO
  end

  def deploy_container_template
    # TODO
  ensure
    # create options may never be saved before unless they were overridden
    save_deployment_options
  end

  def build_deployment_options_from_dialog(_dialog_options)
    # TODO
  end

  # This is called when provision is completed
  def post_provision_configure
    # TODO
  end

  private

  def save_create_options
    # TODO
  end
end
