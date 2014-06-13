module MiqAeMethodService
  class MiqAeServiceMiqHostProvision < MiqAeServiceMiqRequestTask
    expose :miq_host_provision_request, :association => true
    expose :host,                       :association => true

    def status
      ar_method do
        if ['finished', 'provisioned'].include?(@object.state)
          @object.host_rediscovered? ? 'ok' : 'error'
        else
          'retry'
        end
      end
    end

  end
end
