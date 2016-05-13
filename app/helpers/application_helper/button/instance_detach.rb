class ApplicationHelper::Button::InstanceDetach < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if @record.number_of(:cloud_volumes) == 0
      self[:title] = _("%{model} \"%{name}\" has no attached %{volumes}") % {
        :model   => ui_lookup(:table => 'vm_cloud'),
        :name    => @record.name,
        :volumes => ui_lookup(:tables => 'cloud_volumes')
      }
    end
  end

  def disabled?
    @record.number_of(:cloud_volumes) == 0
  end
end
