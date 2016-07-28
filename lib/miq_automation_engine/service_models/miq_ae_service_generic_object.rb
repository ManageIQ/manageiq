module MiqAeMethodService
  class MiqAeServiceGenericObject < MiqAeServiceModelBase
    private

    def method_missing(method_name, *args)
      object_send(method_name, *args)
    end

    def respond_to_missing?(method_name, include_private = false)
      @object.respond_to?(method_name, include_private)
    end
  end
end
