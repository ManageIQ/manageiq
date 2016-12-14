class ApplicationHelper::Button::WidgetGenerateContent < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    @view_context.sandbox[:wtype] != 'm'
  end

  def calculate_properties
    super
    self[:title] = @error_message if @error_message.present?
  end

  def disabled?
    @error_message = _('This Widget content generation is already running or queued up') if @widget_running
    @error_message = _('Widget has to be assigned to a dashboard to generate content') if @record.memberof.count <= 0
    @error_message.present?
  end
end
