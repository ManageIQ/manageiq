module OntapFileShareHelper
  include_concern 'TextualSummary'
  include_summary_presenter(OntapFileShareGraphicalSummaryPresenter)
end
