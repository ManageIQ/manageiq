class ApplicationHelper::Button::ReadOnly < ApplicationHelper::Button::Basic
  needs :@record

  def disabled?
    @error_message = _("This %{klass} is read only and cannot be modified") % {
      :klass => ui_lookup(:model => @record.class.name)
    } if @record.read_only
    @error_message.present?
  end
end
