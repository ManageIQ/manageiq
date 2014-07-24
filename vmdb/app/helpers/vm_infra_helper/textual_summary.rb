module VmCloudHelper::TextualSummary
  extend ActiveSupport::Concern

  included do
    # FIXME: replace with some delegator
    methods = %w(textual_group_properties textual_group_lifecycle textual_group_relationships textual_group_security textual_group_configuration textual_group_datastore_allocation textual_group_datastore_usage textual_group_diagnostics textual_group_storage_relationships textual_group_vmsafe textual_group_miq_custom_attributes textual_group_ems_custom_attributes textual_group_compliance textual_group_power_management textual_group_normal_operating_ranges textual_group_tags textual_group_vdi_endpoint_device textual_group_vdi_connection textual_group_vdi_user)

    methods.each do |method|
      define_method(method) do
        #SummaryPresenter.for_class(self.class).new(@record).#{method}
        VmCloudTextualSummaryPresenter.new(@record).send(method.to_sym)
      end
    end
  end
end
