class AddValidatorToServiceDialogField < ActiveRecord::Migration
  def change
    add_column :dialog_fields, :validator_type, :string
    add_column :dialog_fields, :validator_rule, :string
  end
end
