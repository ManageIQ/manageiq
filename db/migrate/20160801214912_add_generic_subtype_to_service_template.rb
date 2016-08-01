class AddGenericSubtypeToServiceTemplate < ActiveRecord::Migration[5.0]
  def change
    add_column :service_templates, :generic_subtype, :string
    add_index  :service_templates, :generic_subtype
  end
end
