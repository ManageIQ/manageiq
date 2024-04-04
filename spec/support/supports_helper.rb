module Spec
  module Support
    module SupportsHelper
      # when testing a model that receives multiple supports,
      # put this down first to allow the other supports to work fine.
      def stub_supports_all_others(model)
        allow(model.supports_features).to receive(:[]).and_call_original
      end

      # when testing requests, ensure the model supports a certain attribute
      def stub_supports(model, feature = :update, supported: true)
        model = model.class unless model.kind_of?(Class)
        feature = feature.to_sym

        allow(model.supports_features).to receive(:[]).with(feature).and_return(supported)
        # TODO: verify this stub is necessary
        allow(model).to receive(:types_supporting).with(feature).and_return([nil] + model.descendants.map(&:name)) if supported == true
      end

      def stub_supports_not(model, feature = :update, reason = nil)
        stub_supports(model, feature, :supported => (reason || false))
      end
    end
  end
end
