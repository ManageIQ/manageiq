MIQ_OK    = 0
MIQ_WARN  = 4
MIQ_ERROR = 8
MIQ_STOP  = 8
MIQ_ABORT = 16

module Spec
  module Support
    class MiqAeMockService
      include MiqAeMethodService::MiqAeServiceObjectCommon
      include MiqAeMethodService::MiqAeServiceModelLegacy

      attr_reader :root, :object
      attr_accessor :inputs

      def initialize(root, persist_state_hash = {})
        @root = root
        @persist_state_hash = persist_state_hash
        @inputs = {}
      end

      def object=(obj)
        @object = obj
      end

      def set_state_var(name, value)
        @persist_state_hash[name] = value
      end

      def state_var_exist?(name)
        @persist_state_hash.key?(name)
      end

      def get_state_var(name)
        @persist_state_hash[name]
      end

      def log(level, msg)
        $miq_ae_logger.send(level, "<AEMethod> #{msg}")
      end

      def vmdb(model_name, *args)
        service = service_model(model_name)
        args.empty? ? service : service.find(*args)
      end

      def service_model(model_name)
        "MiqAeMethodService::MiqAeService#{model_name}".constantize
      rescue NameError
        service_model_lookup(model_name)
      end
    end
  end
end
