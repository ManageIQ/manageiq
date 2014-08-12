module OntapLogicalDiskHelper::GraphicalSummary
  extend ActiveSupport::Concern

  included do
    methods = %w(graphical_group_relationships graphical_group_infrastructure_relationships)

    methods.each do |method|
      define_method(method) do
        OntapLogicalDiskGraphicalSummaryPresenter.new(self, @record).send(method.to_sym)
      end
    end
  end
end
