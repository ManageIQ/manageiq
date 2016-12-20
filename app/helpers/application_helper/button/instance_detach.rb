class ApplicationHelper::Button::InstanceDetach < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if @record.number_of(:cloud_volumes).zero?
      self[:title] = _("This Instance has no attached Cloud Volumes.")
    end
  end

  def disabled?
    @record.number_of(:cloud_volumes).zero?
  end
end
