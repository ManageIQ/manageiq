class ApplicationHelper::Button::TemplateProvision < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = _("Selected item is not eligible for Provisioning") if disabled?
  end

  def disabled?
    !@record.supports_provisioning?
  end
end
