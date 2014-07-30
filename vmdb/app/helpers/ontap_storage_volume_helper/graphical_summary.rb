module OntapStorageVolumeHelper::GraphicalSummary
  extend ActiveSupport::Concern

  included do
    methods = %w(graphical_group_relationships graphical_group_infrastructure_relationships)

    methods.each do |method|
      define_method(method) do
        OntapStorageVolumeGraphicalSummaryPresenter.new(@record, params, session).send(method.to_sym)
      end
    end
  end
end
