module VmCloudHelper::TextualSummary
  extend ActiveSupport::Concern

  included do
    methods = %w(textual_group_properties textual_group_lifecycle
                 textual_group_vm_cloud_relationships
                 textual_group_template_cloud_relationships textual_group_security
                 textual_group_configuration textual_group_diagnostics textual_group_vmsafe
                 textual_group_miq_custom_attributes textual_group_ems_custom_attributes
                 textual_group_compliance textual_group_power_management textual_group_tags)

    methods.each do |method|
      define_method(method) do
        VmCloudTextualSummaryPresenter.new(@record, params, session).send(method.to_sym)
      end
    end
  end
end
