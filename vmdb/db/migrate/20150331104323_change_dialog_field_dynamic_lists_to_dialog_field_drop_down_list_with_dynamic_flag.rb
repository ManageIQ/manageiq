class ChangeDialogFieldDynamicListsToDialogFieldDropDownListWithDynamicFlag < ActiveRecord::Migration
  class DialogField < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time("Converting DialogFieldDynamicLists to DialogFieldDropDowns with the dynamic flag set to true") do
      DialogField.where(:type => "DialogFieldDynamicList").each do |dialog_field_dynamic_list|
        dialog_field_dynamic_list.type = "DialogFieldDropDownList"
        dialog_field_dynamic_list.dynamic = true
        dialog_field_dynamic_list.save
      end
    end
  end

  def down
    say_with_time("Converting DialogFieldDropDowns with dynamic flag true to DialogFieldDynamicLists") do
      DialogField.where(:type => "DialogFieldDropDownList", :dynamic => true).each do |dialog_field_drop_down|
        dialog_field_drop_down.type = "DialogFieldDynamicList"
        dialog_field_drop_down.dynamic = false
        dialog_field_drop_down.save
      end
    end
  end
end
