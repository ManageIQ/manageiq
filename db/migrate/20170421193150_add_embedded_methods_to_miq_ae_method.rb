class AddEmbeddedMethodsToMiqAeMethod < ActiveRecord::Migration[5.0]
  class MiqAeMethod < ActiveRecord::Base; end
  def up
    add_column :miq_ae_methods, :embedded_methods, :text, :array => true, :comment => "Ordered list of embedded method names"
    say_with_time("Updating existing miq_ae_methods embedded methods") do
      MiqAeMethod.update_all(:embedded_methods => [])
    end
  end

  def down
    remove_column :miq_ae_methods, :embedded_methods
  end
end
