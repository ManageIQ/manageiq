module VmCloudHelper::GraphicalSummary
  extend ActiveSupport::Concern

  included do
    # FIXME: replace with some delegator
    methods = %w(graphical_group_properties graphical_group_lifecycle graphical_group_vm_cloud_relationships graphical_group_template_cloud_relationships graphical_group_security graphical_group_configuration graphical_group_diagnostics)

    methods.each do |method|
      define_method(method) do
        #SummaryPresenter.for_class(self.class).new(@record).#{method}
        VmCloudGraphicalSummaryPresenter.new(@record).send(method.to_sym)
      end
    end
  end
end
