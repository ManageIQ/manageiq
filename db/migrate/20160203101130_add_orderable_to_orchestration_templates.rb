class AddOrderableToOrchestrationTemplates < ActiveRecord::Migration
  class OrchestrationTemplate < ActiveRecord::Base; end

  def self.up
    add_column :orchestration_templates, :orderable, :boolean

    say_with_time("Update OrchestrationTemplate orderable") do
      OrchestrationTemplate.update_all(:orderable => true)
    end
  end

  def self.down
    remove_column :orchestration_templates, :orderable
  end
end
