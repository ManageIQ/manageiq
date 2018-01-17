class MiqWidgetContent < ApplicationRecord
  belongs_to  :miq_widget
  belongs_to  :miq_report_result

  def self.display_name(number = 1)
    n_('Widget Content', 'Widget Contents', number)
  end
end
