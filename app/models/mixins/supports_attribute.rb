module SupportsAttribute
  extend ActiveSupport::Concern

  class_methods do
    # define an attribute that is used by the ui to detect that a feature is supported
    # These are often defined with an actual supports feature,
    # but it is often not necessary and we are trying avoid
    #
    # This is mostly used instead of supports but is very related to the supports end goal
    #
    # examples:
    #
    #   a) supports_attribute :supports_create_security_group, child_model: SecurityGroup, feature: create
    #
    #   def supports_create_security_group
    #     ext_management_system.class::ChildModel.supports?(feature)
    #   end
    #
    #   NOTE: we could derive this name, but it is too hard to search
    #
    #   b) supports_attribute feature: :add_volume_mapping
    #
    #   def supports_add_volume_mapping
    #     supports?(:add_volume_mapping)
    #   end
    #
    def supports_attribute(colname = nil, feature: :create, child_model: nil)
      feature = feature.to_sym

      if child_model
        define_method(colname) do
          class_by_ems(child_model)&.supports?(feature) || false
        end
      else
        colname ||= "supports_#{feature}"

        define_method(colname) do
          supports?(feature)
        end
      end

      virtual_attribute colname, :boolean
    end
  end
end
