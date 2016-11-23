class ApplicationHelper::Button::CustomizationTemplateNew < ApplicationHelper::Button::CustomizationTemplate
  def visible?
    !system?
  end
end
