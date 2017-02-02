module MiqAeMethodService
  class MiqAeServiceServiceAnsiblePlaybook < MiqAeServiceService
    expose :preprocess
    expose :execute
    expose :wait_for_completion
    expose :refresh_provider
    expose :check_refreshed
    expose :postprocess
  end
end
