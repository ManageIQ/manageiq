class ExpandDialogFieldDefaultValueSize < ActiveRecord::Migration
  class DialogField < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def up
    change_column :dialog_fields, :default_value, :text

    say_with_time("Migrate data from reserved table") do
      DialogField.includes(:reserved_rec).each do |d|
        d.reserved_hash_migrate(:default_value) if d.reserved_hash_get(:default_value)
      end      
    end
  end

  def down
    say_with_time("Migrate data to reserved table") do
      DialogField.includes(:reserved_rec).each do |d|
        d.reserved_hash_set(:default_value, d.default_value) if d.default_value
        d.save!
      end
    end

    change_column :dialog_fields, :default_value, :string
  end
end
