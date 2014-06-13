class AddTypeToCustomizationTemplate < ActiveRecord::Migration
  class CustomizationTemplate < ActiveRecord::Base
    self.inheritance_column = :_type_disabled    # disable STI
  end

  def up
    add_column :customization_templates, :type, :string

    say_with_time("Migrating all templates to CustomizationTemplateKickstart") do
      CustomizationTemplate.update_all(:type => "CustomizationTemplateKickstart")
    end
  end

  def down
    remove_column :customization_templates, :type
  end
end
