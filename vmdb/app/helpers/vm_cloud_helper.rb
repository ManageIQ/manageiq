module VmCloudHelper
  include VmHelper
  include_summary_presenter(VmCloudTextualSummaryPresenter)
  include_summary_presenter(VmCloudGraphicalSummaryPresenter)
end
