module ApplicationHelper::Dialogs
  def dialog_dropdown_select_values(field, _selected_value, category_tags = nil)
    values = []
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

  def textbox_tag_options(field, url, auto_refresh_options_hash)
    tag_options = {
      :maxlength => 50,
      :class     => "dynamic-text-box-#{field.id} form-control"
    }

    extra_options = {"data-miq_observe" => {
      :url => url,
    }.merge(auto_refresh_options(field, auto_refresh_options_hash)).to_json}

    add_options_unless_read_only(extra_options, tag_options, field)
  end

  def textarea_tag_options(field, url, auto_refresh_options_hash)
    tag_options = {
      :class     => "dynamic-text-area-#{field.id} form-control",
      :size      => "50x6"
    }

    extra_options = {"data-miq_observe" => {
      :url => url,
    }.merge(auto_refresh_options(field, auto_refresh_options_hash)).to_json}

    add_options_unless_read_only(extra_options, tag_options, field)
  end

  def checkbox_tag_options(field, url, auto_refresh_options_hash)
    tag_options = {:class => "dynamic-checkbox-#{field.id}"}
    miq_observe_options = {
      :url => url
    }.merge(auto_refresh_options(field, auto_refresh_options_hash)).to_json
    extra_options = {
      "data-miq_sparkle_on"       => true,
      "data-miq_sparkle_off"      => true,
      "data-miq_observe_checkbox" => miq_observe_options
    }

    add_options_unless_read_only(extra_options, tag_options, field)
  end

  def date_tag_options(field, url, auto_refresh_options_hash)
    tag_options = {:class => "css1 dynamic-date-#{field.id}", :readonly => "true"}
    miq_observe_options = {
      :url => url
    }.merge(auto_refresh_options(field, auto_refresh_options_hash)).to_json
    extra_options = {"data-miq_observe_date" => miq_observe_options}

    add_options_unless_read_only(extra_options, tag_options, field)
  end

  def time_tag_options(field, url, hour_or_min, auto_refresh_options_hash)
    tag_options = {:class => "dynamic-date-#{hour_or_min}-#{field.id}"}
    extra_options = {"data-miq_observe" => {
      :url => url
    }.merge(auto_refresh_options(field, auto_refresh_options_hash)).to_json}

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
      :class   => field.id,
      :value   => value,
      :name    => field.name,
      :checked => selected_value.to_s == value.to_s ? '' : nil
    }

    add_options_unless_read_only({}, tag_options, field)
  end

  def default_value_form_options(field_type, field_values, field_default_value)
    no_default_value = [["<#{_('None')}>", nil]]
    if field_values.empty?
      values = no_default_value
    else
      values = field_values.collect(&:reverse)
      values = no_default_value + values if field_type == "DialogFieldRadioButton"
    end

    selected = field_default_value || nil
    options_for_select(values, selected)
  end

  def build_auto_refreshable_field_indicies(workflow)
    auto_refreshable_field_indicies = []

    workflow.dialog.dialog_tabs.each_with_index do |tab, tab_index|
      tab.dialog_groups.each_with_index do |group, group_index|
        group.dialog_fields.each_with_index do |field, field_index|
          next unless field.auto_refresh || field.trigger_auto_refresh

          auto_refreshable_field_indicies << {
            :tab_index    => tab_index,
            :group_index  => group_index,
            :field_index  => field_index,
            :auto_refresh => !!field.auto_refresh
          }
        end
      end
    end

    auto_refreshable_field_indicies
  end

  def auto_refresh_listening_options(options, trigger_override)
    options.merge(:trigger => trigger_override)
  end

  private

  def auto_refresh_options(field, auto_refresh_options_hash)
    if field.trigger_auto_refresh
      {
        :auto_refresh                    => true,
        :tab_index                       => auto_refresh_options_hash[:tab_index],
        :group_index                     => auto_refresh_options_hash[:group_index],
        :field_index                     => auto_refresh_options_hash[:field_index],
        :auto_refreshable_field_indicies => auto_refresh_options_hash[:auto_refreshable_field_indicies],
        :current_index                   => auto_refresh_options_hash[:current_index],
        :trigger                         => auto_refresh_options_hash[:trigger]
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
