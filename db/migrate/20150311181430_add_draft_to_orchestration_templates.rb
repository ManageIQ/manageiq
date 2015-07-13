class AddDraftToOrchestrationTemplates < ActiveRecord::Migration
  class OrchestrationTemplate < ActiveRecord::Base; end

  def self.up
    add_column :orchestration_templates, :draft, :boolean

    say_with_time("Update OrchestrationTemplate draft") do
      OrchestrationTemplate.update_all(:draft => false)
    end
  end

  def self.down
    remove_column :orchestration_templates, :draft
  end
end
