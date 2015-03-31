module ApplicationHelper::Dialogs
  def dialog_dropdown_select_values(field, selected_value, category_tags = nil)
    values = []
    if !field.required
      values.push(["<None>", nil])
    elsif selected_value.blank?
      values.push(["<Choose>", nil])
    end
    if field.type.include?("DropDown")
      values += field.values.collect(&:reverse)
    elsif field.type.include?("TagControl")
      values += category_tags
    end
    return values
  end

  def disable_check_box?
    category = DialogFieldTagControl.allowed_tag_categories.detect {|cat| cat[:id].to_s == @edit[:field_category]}
    category && category[:single_value]
  end

  def textbox_tag_options(field, url)
    tag_options = {
      :maxlength => 50,
      :class     => "dynamic-text-box-#{field.id}"
    }
    extra_options = {"data-miq_observe" => {:interval => '.5', :url => url}.to_json}

    add_options_unless_read_only(extra_options, tag_options, field)
  end

  def textarea_tag_options(field, url)
    tag_options = {
      :class     => "dynamic-text-area-#{field.id}",
      :maxlength => 8192,
      :size      => "50x6"
    }
    extra_options = {"data-miq_observe" => {:interval => '.5', :url => url}.to_json}

    add_options_unless_read_only(extra_options, tag_options, field)
  end

  private

  def add_options_unless_read_only(options_to_add, options_to_add_to, field)
    if field.read_only
      options_to_add_to.merge!(:disabled => true, :title => "This element is disabled because it is read only")
    else
      options_to_add_to.merge!(options_to_add)
    end
  end
end
