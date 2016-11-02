class ApplicationHelper::Button::MiddlewareAction < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    @record.try(:product) != 'Hawkular' && @record.try(:middleware_server).try(:product) != 'Hawkular'
  end
end
