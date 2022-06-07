module Spec
  module Support
    module SupportsHelper
      # when testing a model that receives multiple supports,
      # put this down first to allow the other supports to work fine.
      def stub_supports_all_others(model)
        allow_any_instance_of(model).to receive(:supports?).and_call_original
      end

      # when testing requests, ensure the model supports a certain attribute
      def stub_supports(model, feature = :update, supported: true)
        model = model.class unless model.kind_of?(Class)
        feature = feature.to_sym

        receive_supports = receive(:supports?).with(feature).and_return(supported)
        allow(model).to receive_supports
        allow_any_instance_of(model).to receive_supports

        allow(model).to receive(:types_supporting).with(feature).and_return([nil] + model.descendants.map(&:name))
      end

      def stub_supports_not(model, feature = :update, reason = nil)
        model = model.class unless model.kind_of?(Class)
        feature = feature.to_sym

        stub_supports(model, feature, :supported => false)

        reason ||= SupportsFeatureMixin.reason_or_default(reason)
        receive_reason = receive(:unsupported_reason).with(feature).and_return(reason)
        allow(model).to(receive_reason)
        allow_any_instance_of(model).to(receive_reason)
      end
    end
  end
end
