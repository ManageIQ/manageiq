class AddValidatorToServiceDialogField < ActiveRecord::Migration[4.2]
  def change
    add_column :dialog_fields, :validator_type, :string
    add_column :dialog_fields, :validator_rule, :string
  end
end
