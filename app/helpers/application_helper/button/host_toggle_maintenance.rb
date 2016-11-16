class ApplicationHelper::Button::HostToggleMaintenance < ApplicationHelper::Button::Basic
  def disabled?
    !(@record.is_available?(:set_node_maintenance) && @record.is_available?(:unset_node_maintenance))
  end

  def calculate_properties
    super
    self[:title] = _("Maintenance mode is not supported for this host") if disabled?
  end
end
