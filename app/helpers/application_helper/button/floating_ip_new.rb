class ApplicationHelper::Button::FloatingIpNew < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if disabled?
      self[:title] = _("No cloud providers support creating floating IPs.")
    end
  end

  # disable button if no active providers support create action
  def disabled?
    EmsNetwork.all.none? { |ems| FloatingIp.class_by_ems(ems).supports_create? }
  end
end
