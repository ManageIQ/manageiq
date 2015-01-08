module MiqAeMethodService
  class MiqAeServiceMiqEvent < MiqAeServiceEventStream
    def process_evm_event
      ar_method { @object.process_evm_event }
    end
  end
end
