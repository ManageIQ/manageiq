FactoryGirl.define do
  factory :dialog_field do
  end

  factory :dialog_field_text_box, :parent => :dialog_field, :class => "DialogFieldTextBox" do
  end

  factory :dialog_field_text_area_box, :parent => :dialog_field_text_box, :class => "DialogFieldTextAreaBox" do
  end

  factory :dialog_field_tag_control, :parent => :dialog_field, :class => "DialogFieldTagControl" do
  end

  factory :dialog_field_button, :parent => :dialog_field, :class => "DialogFieldButton" do
  end

  factory :dialog_field_check_box, :parent => :dialog_field, :class => "DialogFieldCheckBox" do
  end

  factory :dialog_field_sorted_item, :parent => :dialog_field, :class => "DialogFieldSortedItem" do
  end

  factory :dialog_field_drop_down_list, :parent => :dialog_field_sorted_item, :class => "DialogFieldDropDownList" do
  end

  factory :dialog_field_radio_button, :parent => :dialog_field_sorted_item, :class => "DialogFieldDropDownList" do
  end

  factory :dialog_field_dynamic_list, :parent => :dialog_field_sorted_item, :class => "DialogFieldDynamicList" do
  end

  factory :dialog_field_date_control, :parent => :dialog_field, :class => "DialogFieldDateControl" do
  end

  factory :dialog_field_date_time_control, :parent => :dialog_field_date_control, :class => "DialogFieldDateTimeControl" do
  end
end
