class ApplicationHelper::Button::InstanceDetach < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if @record.number_of(:cloud_volumes).zero?
      self[:title] = _("This %{model} has no attached %{volumes}.") % {
        :model   => ui_lookup(:table => 'vm_cloud'),
        :volumes => ui_lookup(:tables => 'cloud_volumes')
      }
    end
  end

  def disabled?
    @record.number_of(:cloud_volumes).zero?
  end
end
