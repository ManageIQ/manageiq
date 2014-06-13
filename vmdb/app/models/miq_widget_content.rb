class MiqWidgetContent < ActiveRecord::Base
  belongs_to  :miq_widget
  belongs_to  :miq_report_result
end
