require "spec_helper"
require_migration

describe ChangeDialogFieldDynamicListsToDialogFieldDropDownListWithDynamicFlag do
  let(:dialog_field_stub) { migration_stub(:DialogField) }

  migration_context :up do
    it "migrates existing dynamic lists to drop down lists" do
      dialog_field = dialog_field_stub.create!(:type => "DialogFieldDynamicList")

      migrate

      dialog_field.reload
      expect(dialog_field.type).to eq("DialogFieldDropDownList")
      expect(dialog_field.dynamic).to be_true
    end
  end

  migration_context :down do
    it "migrates existing drop down lists with dynamic flag to dynamic lists" do
      dialog_field = dialog_field_stub.create!(:type => "DialogFieldDropDownList")
      dialog_field_2 = dialog_field_stub.create!(:dynamic => true, :type => "DialogFieldDropDownList")

      migrate

      dialog_field.reload
      dialog_field_2.reload
      expect(dialog_field.type).to eq("DialogFieldDropDownList")
      expect(dialog_field.dynamic).to be_false
      expect(dialog_field_2.type).to eq("DialogFieldDynamicList")
      expect(dialog_field_2.dynamic).to be_false
    end
  end
end
