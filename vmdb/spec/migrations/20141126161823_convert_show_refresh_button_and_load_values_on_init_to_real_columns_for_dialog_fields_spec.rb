require "spec_helper"
require Rails.root.join("db/migrate/20141126161823_convert_show_refresh_button_and_load_values_on_init_to_real_columns_for_dialog_fields.rb")

describe ConvertShowRefreshButtonAndLoadValuesOnInitToRealColumnsForDialogFields do
  let(:dialog_field_stub) { migration_stub(:DialogField) }

  migration_context :up do
    it "migrates options[:show_refresh_button] to a column and removes that option" do
      dialog_field = dialog_field_stub.create!(
        :name    => "test",
        :options => {:show_refresh_button => true, :load_values_on_init => true}
      )

      migrate

      dialog_field.reload
      expect(dialog_field.options[:show_refresh_button]).to be_nil
      expect(dialog_field.show_refresh_button).to be(true)
    end

    it "migrates options[:load_values_on_init] to a column and removes that option" do
      dialog_field = dialog_field_stub.create!(
        :name    => "test",
        :options => {:show_refresh_button => true, :load_values_on_init => true}
      )

      migrate

      dialog_field.reload
      expect(dialog_field.options[:load_values_on_init]).to be_nil
      expect(dialog_field.load_values_on_init).to be(true)
    end
  end

  migration_context :down do
    it "migrates the column back to options[:show_refresh_button]" do
      dialog_field = dialog_field_stub.create!(
        :name                => "test",
        :show_refresh_button => true,
        :load_values_on_init => true,
        :options             => {}
      )

      migrate

      dialog_field.reload
      expect(dialog_field.options[:show_refresh_button]).to be(true)
    end

    it "migrates the column back to options[:load_values_on_init]" do
      dialog_field = dialog_field_stub.create!(
        :name                => "test",
        :show_refresh_button => true,
        :load_values_on_init => true,
        :options             => {}
      )

      migrate

      dialog_field.reload
      expect(dialog_field.options[:load_values_on_init]).to be(true)
    end
  end
end
