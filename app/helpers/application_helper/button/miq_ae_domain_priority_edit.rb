class ApplicationHelper::Button::MiqAeDomainPriorityEdit < ApplicationHelper::Button::MiqAeDefaultNoRecord
  def disabled?
    (User.current_tenant.visible_domains.length < 2)
  end

  def calculate_properties
    super
    self[:title] = N_("You need two or more domains to edit domain priorities") if disabled?
  end
end
