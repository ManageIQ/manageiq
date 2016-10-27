class ApplicationHelper::Button::AbGroupReorder < ApplicationHelper::Button::AbGroupEdit
  def disabled?
    if @view_context.x_active_tree == :ab_tree
      @error_message = ERROR_MSG if single_set?
    elsif single_button_or_set?
      @error_message = ERROR_MSG
    end
    @error_message.present?
  end

  private

  ERROR_MSG = N_('Only more than 1 Custom Button Groups can be reordered')

  def single_set?
    CustomButtonSet.find_all_by_class_name(@view_context.x_node.split('_').last).count <= 1
  end

  def single_button_or_set?
    service_template_button_or_set_count <= 1
  end

  def service_template_button_or_set_count
    rec_id = @view_context.x_node.split('_').last.split('-').last
    st = ServiceTemplate.find_by_id(rec_id)
    st.custom_button_sets.count + st.custom_buttons.count
  end
end
