module MiqAeMethodService
  class MiqAeServiceMiqRequestTask < MiqAeServiceModelBase
    require_relative "mixins/miq_ae_service_miq_request_mixin"
    include MiqAeServiceMiqRequestMixin

    expose :execute, :method => :execute_queue, :override_return => true
    expose :miq_request,       :association => true
    expose :miq_request_task,  :association => true
    expose :miq_request_tasks, :association => true
    expose :source,            :association => true
    expose :destination,       :association => true
    undef :phase_context

    def message=(msg)
      ar_method { @object.update_and_notify_parent(:message => msg) unless @object.state == 'finished' }
    end

    def finished(msg)
      object_send(:update_and_notify_parent, :state => 'finished', :message => msg)
    end

  end
end
