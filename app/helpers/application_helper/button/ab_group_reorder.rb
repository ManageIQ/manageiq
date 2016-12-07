class ApplicationHelper::Button::AbGroupReorder < ApplicationHelper::Button::AbGroupEdit
  def disabled?
    @error_message = _('Only more than 1 Custom Button Groups can be %{action}') %
                     {:action => @action} unless reorderable?
    @error_message.present?
  end

  private

  def reorderable?
    @view_context.x_active_tree == :ab_tree ? multiple_button_sets? : multiple_service_button_or_sets?
  end

  def multiple_button_sets?
    CustomButtonSet.find_all_by_class_name(@view_context.x_node.split('_').last).count > 1
  end

  def multiple_service_button_or_sets?
    service_template_button_or_set_count > 1
  end

  def service_template_button_or_set_count
    rec_id = @view_context.x_node.split('_').last.split('-').last
    st = ServiceTemplate.find(rec_id)
    st.custom_button_sets.count + st.custom_buttons.count
  end
end
