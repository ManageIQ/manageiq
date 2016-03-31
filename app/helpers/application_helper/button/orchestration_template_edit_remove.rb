class ApplicationHelper::Button::OrchestrationTemplateEditRemove < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if @view_context.x_active_tree == :ot_tree && @record
      self[:enabled] = !@record.in_use?
      self[:title] = if self[:id] =~ /_edit$/
                       _('Orchestration Templates that are in use cannot be edited')
                     else
                       _('Orchestration Templates that are in use cannot be removed')
                     end
    end
  end
end
