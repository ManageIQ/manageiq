module VmHelper::GraphicalSummary
  extend ActiveSupport::Concern

  included do
    methods = %w(graphical_group_properties graphical_group_lifecycle
                 graphical_group_relationships graphical_group_vm_cloud_relationships
                 graphical_group_template_cloud_relationships graphical_group_security
                 graphical_group_configuration graphical_group_diagnostics
                 graphical_group_storage_relationships)

    methods.each do |method|
      define_method(method) do
        VmGraphicalSummaryPresenter.new(self, @record).send(method.to_sym)
      end
    end
  end
end
