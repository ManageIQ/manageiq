class ApplicationHelper::Button::NetworkRouterNew < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if disabled?
      self[:title] = _("No cloud providers support creating network routers.")
    end
  end

  # disable button if no active providers support create action
  def disabled?
    EmsNetwork.all.none? { |ems| NetworkRouter.class_by_ems(ems).supports_create_network_router? }
  end
end
