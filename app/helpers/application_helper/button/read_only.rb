class ApplicationHelper::Button::ReadOnly < ApplicationHelper::Button::Basic
  needs :@record

  def disabled?
    @record.read_only
  end

  def calculate_properties
    super
    self[:title] = _(
      "This %{klass} is read only and cannot be modified" % {
        :klass => ui_lookup(:model => @record.class.name)
      }
    ) if disabled?
  end
end
