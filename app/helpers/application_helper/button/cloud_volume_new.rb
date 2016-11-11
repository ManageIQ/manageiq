class ApplicationHelper::Button::CloudVolumeNew < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if disabled?
      self[:title] = _("No cloud providers support creating cloud volumes.")
    end
  end

  def disabled?
    ems_clouds = EmsCloud.all
    # if any connected provider supports this action,
    # we can enable the button.
    ems_clouds.each do |ems|
      return false if CloudVolume.class_by_ems(ems).supports_create?
    end
    true
  end
end
