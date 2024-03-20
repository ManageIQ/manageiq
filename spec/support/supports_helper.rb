module Spec
  module Support
    module SupportsHelper
      # when testing a model that receives multiple supports,
      # put this down first to allow the other supports to work fine.
      def stub_supports_all_others(model)
        allow(model).to receive(:unsupported_reason).and_call_original
      end

      # when testing requests, ensure the model supports a certain attribute
      def stub_supports(model, feature = :update, supported: true, reason: nil)
        model = model.class unless model.kind_of?(Class)
        feature = feature.to_sym

        reason = supported ? nil : (reason || SupportsFeatureMixin.default_supports_reason)
        allow(model).to receive(:unsupported_reason).with(feature, :instance => anything).and_return(reason)

        if supported
          allow(model).to receive(:types_supporting).with(feature).and_return([nil] + model.descendants.map(&:name))
        end
      end

      def stub_supports_not(model, feature = :update, reason = nil)
        stub_supports(model, feature, :supported => false, :reason => reason)
      end
    end
  end
end
