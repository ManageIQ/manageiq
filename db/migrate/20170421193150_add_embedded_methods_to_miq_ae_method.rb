class AddEmbeddedMethodsToMiqAeMethod < ActiveRecord::Migration[5.0]
  def change
    add_column :miq_ae_methods, :embedded_methods, :string, :array => true
  end
end
