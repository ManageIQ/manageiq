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
    values
  end

  def disable_check_box?
    category = DialogFieldTagControl.allowed_tag_categories.detect { |cat| cat[:id].to_s == @edit[:field_category] }
    category && category[:single_value]
  end

  def hour_select_options(value)
    options_for_select(Array.new(24) { |i| i.to_s.rjust(2, '0') }, value)
  end

  def minute_select_options(value)
    options_for_select(Array.new(59) { |i| i.to_s.rjust(2, '0') }, value)
  end

  def textbox_tag_options(field, url)
    tag_options = {
      :maxlength => 50,
      :class     => "dynamic-text-box-#{field.id} form-control"
    }

    extra_options = {"data-miq_observe" => {
      :url      => url,
    }.merge(auto_refresh_options(field)).to_json}

    add_options_unless_read_only(extra_options, tag_options, field)
  end

  def textarea_tag_options(field, url)
    tag_options = {
      :class     => "dynamic-text-area-#{field.id} form-control",
      :size      => "50x6"
    }

    extra_options = {"data-miq_observe" => {
      :url      => url,
    }.merge(auto_refresh_options(field)).to_json}

    add_options_unless_read_only(extra_options, tag_options, field)
  end

  def checkbox_tag_options(field, url)
    tag_options = {:class => "dynamic-checkbox-#{field.id}"}
    extra_options = {
      "data-miq_sparkle_on"       => true,
      "data-miq_sparkle_off"      => true,
      "data-miq_observe_checkbox" => {:url => url}.merge(auto_refresh_options(field)).to_json
    }

    add_options_unless_read_only(extra_options, tag_options, field)
  end

  def date_tag_options(field, url)
    tag_options = {:class => "css1 dynamic-date-#{field.id}", :readonly => "true"}
    extra_options = {"data-miq_observe_date" => {:url => url}.merge(auto_refresh_options(field)).to_json}

    add_options_unless_read_only(extra_options, tag_options, field)
  end

  def time_tag_options(field, url, hour_or_min)
    tag_options = {:class => "dynamic-date-#{hour_or_min}-#{field.id}"}
    extra_options = {"data-miq_observe" => {:url => url}.merge(auto_refresh_options(field)).to_json}

    add_options_unless_read_only(extra_options, tag_options, field)
  end

  def drop_down_options(field, url)
    tag_options = {:class => "dynamic-drop-down-#{field.id} selectpicker"}
    extra_options = {
      "data-miq_sparkle_on"  => true,
      "data-miq_sparkle_off" => true,
      "data-live-search"     => true
      # data-miq_observe functionality is handled by dialogFieldRefresh.initializeDialogSelectPicker here
    }

    add_options_unless_read_only(extra_options, tag_options, field)
  end

  def radio_options(field, url, value, selected_value)
    tag_options = {
      :type    => 'radio',
      :id      => field.id,
      :value   => value,
      :name    => field.name,
      :checked => selected_value.to_s == value.to_s ? '' : nil
    }

    auto_refresh_string = field.trigger_auto_refresh ? "dialogFieldRefresh.triggerAutoRefresh('#{field.id}', '#{field.trigger_auto_refresh}');" : ""

    extra_options = {
      # FIXME: when removing remote_function, note that onclick should really be onchange instead
      :onclick  => auto_refresh_string + remote_function(
        :with     => "miqSerializeForm('dynamic-radio-#{field.id}')",
        :url      => url,
        :loading  => "miqSparkle(true);",
        :complete => "miqSparkle(false);"
      )
    }

    add_options_unless_read_only(extra_options, tag_options, field)
  end

  private

  def auto_refresh_options(field)
    if field.trigger_auto_refresh
      {
        :auto_refresh => true,
        :field_id     => field.id.to_s,
        :trigger      => field.trigger_auto_refresh.to_s
      }
    else
      {}
    end
  end

  def add_options_unless_read_only(options_to_add, options_to_add_to, field)
    if field.read_only
      options_to_add_to.merge!(:disabled => true, :title => _("This element is disabled because it is read only"))
    else
      options_to_add_to.merge!(options_to_add)
    end
  end
end
