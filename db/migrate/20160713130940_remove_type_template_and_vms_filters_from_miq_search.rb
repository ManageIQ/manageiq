class RemoveTypeTemplateAndVmsFiltersFromMiqSearch < ActiveRecord::Migration[5.0]
  class MiqSearch < ActiveRecord::Base
  end

  def up
    say_with_time('Remove Type / Template and Type / VM from VMs filters') do
      ["default_Type / Template", "default_Type / VM"].each do |name|
        MiqSearch.find_by(:name => name).try(:delete)
      end
    end
  end

  def down
    # Rolling back this migration requires a serialized MiqExpression object, which is app-code dependent.
    # Before this code change and migration, the seeds will reload these filters for you.
  end
end
