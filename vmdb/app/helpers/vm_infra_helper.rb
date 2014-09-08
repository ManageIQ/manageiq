module VmInfraHelper
  include VmHelper
  include_summary_presenter(VmInfraGraphicalSummaryPresenter)
  include_summary_presenter(VmInfraTextualSummaryPresenter)
end
