module MiqAeMethodService
  class MiqAeServiceMiqHostProvisionRequest < MiqAeServiceMiqRequest
    expose :miq_host_provisions, :association => true

    def ci_type
      'host'
    end
  end
end
