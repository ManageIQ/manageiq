class MiqUiWorker::Runner < MiqWorker::Runner
  include MiqWebServerRunnerMixin

  def prepare
    super
    MiqApache::Control.start if MiqEnvironment::Command.is_podified?
  end
end
