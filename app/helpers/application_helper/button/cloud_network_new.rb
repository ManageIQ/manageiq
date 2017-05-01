class ApplicationHelper::Button::CloudNetworkNew < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if disabled?
      self[:title] = _("No cloud providers support creating cloud networks.")
    end
  end

  # disable button if no active providers support create action
  def disabled?
    EmsNetwork.all.none? { |ems| CloudNetwork.class_by_ems(ems).supports_create? }
  end
end
