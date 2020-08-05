FactoryBot.define do
  factory :dialog_field do
    name { "Dialog Field" }
  end

  factory :dialog_field_sorted_item, :parent => :dialog_field, :class => "DialogFieldSortedItem"
  factory :dialog_field_tag_control, :parent => :dialog_field, :class => "DialogFieldTagControl"
  factory :dialog_field_text_box,    :parent => :dialog_field, :class => "DialogFieldTextBox"

  factory :dialog_field_drop_down_list, :parent => :dialog_field_sorted_item, :class => "DialogFieldDropDownList"
end
