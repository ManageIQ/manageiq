class ApplicationHelper::Button::CloudVolumeNew < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if disabled?
      self[:title] = _("No cloud providers support creating cloud volumes.")
    end
  end

  # disable button if no active providers support create action
  def disabled?
    EmsCloud.all.none? { |ems| CloudVolume.class_by_ems(ems).supports_create? }
  end
end
