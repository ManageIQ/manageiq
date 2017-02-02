module MiqAeMethodService
  class MiqAeServiceServiceGeneric < MiqAeServiceService
    expose :preprocess
    expose :execute
    expose :check_completed
    expose :refresh
    expose :check_refreshed
    expose :postprocess
  end
end
