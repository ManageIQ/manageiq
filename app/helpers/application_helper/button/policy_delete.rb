class ApplicationHelper::Button::PolicyDelete < ApplicationHelper::Button::PolicyButton

  def disabled?
    !@policy.memberof.empty?
  end

  def calculate_properties
    super
    self[:title] = _("Policies that belong to Profiles can not be deleted") if disabled?
  end
end
