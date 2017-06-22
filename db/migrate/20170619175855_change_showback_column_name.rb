class ChangeShowbackColumnName < ActiveRecord::Migration[5.0]
  def change
    rename_column :showback_rates, :fixed_rate_subunit, :fixed_rate_subunits
    rename_column :showback_rates, :variable_rate_subunit, :variable_rate_subunits
  end
end
