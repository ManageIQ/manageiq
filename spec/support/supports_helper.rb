module Spec
  module Support
    module SupportsHelper
      # when testing requests, ensure the model supports a certain attribute
      # @param (Symbol) feature which supports feature is supported (e.g.: :create, :update, :delete)
      # @param (Array|Nil) fields value to stub params_for_* (default: nil don't stub)
      def stub_supports(model, feature = :update, supported: true, fields: nil)
        model = model.class unless model.kind_of?(Class)

        receive_supports = receive(:supports?).with(feature).and_return(supported)
        allow(model).to receive_supports
        allow_any_instance_of(model).to receive_supports

        return if fields.nil?

        receive_this_message = receive("params_for_#{feature}".to_sym).and_return("fields" => fields)
        allow(model).to(receive_this_message)                 # only useful for create
        allow_any_instance_of(model).to(receive_this_message) # only useful for update
      end

      def stub_supports_not(model, feature = :update, reason = nil)
        model = model.class unless model.kind_of?(Class)

        stub_supports(model, feature, :supported => false)

        if reason
          receive_reason = receive(:unsupported_reason).with(feature).and_return(reason)
          allow(model).to(receive_reason)
          allow_any_instance_of(model).to(receive_reason)
        end
      end
    end
  end
end
