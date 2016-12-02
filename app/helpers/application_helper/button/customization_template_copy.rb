class ApplicationHelper::Button::CustomizationTemplateCopy < ApplicationHelper::Button::CustomizationTemplate
  def visible?
    !root?
  end
end
