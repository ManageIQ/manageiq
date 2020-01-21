class MiqReportResultDetail < ApplicationRecord
  belongs_to  :miq_report_result

  def self.display_name(number = 1)
    n_('Report Result Detail', 'Report Result Details', number)
  end
end
