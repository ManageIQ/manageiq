class ApplicationHelper::Button::MiddlewareServerAction < ApplicationHelper::Button::Basic

  def visible?
    !@record.present? ||
      (@record.try(:product) != 'Hawkular' && @record.try(:middleware_server).try(:product) != 'Hawkular')
  end
end
