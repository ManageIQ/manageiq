module ApplicationHelper::Dialogs

  def dialog_dropdown_select_values(field, selected_value, category_tags = nil)
    values = []
    if !field.required
      values.push(["<None>", nil])
    elsif selected_value.blank?
      values.push(["<Choose>", nil])
    end
    if field.type.include?("DropDown")
      values += field.values.collect{|v| v.reverse}
    elsif field.type.include?("TagControl")
      values += category_tags
    end
    return values
  end

  def disable_check_box?
    category = DialogFieldTagControl.allowed_tag_categories.detect {|cat| cat[:id].to_s == @edit[:field_category]}
    category && category[:single_value]
  end

end
