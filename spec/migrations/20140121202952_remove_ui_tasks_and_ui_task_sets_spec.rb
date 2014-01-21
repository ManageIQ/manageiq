require_relative '../spec_helper'
require Rails.root.join("db/migrate/20140121202952_remove_ui_tasks_and_ui_task_sets")

describe RemoveUiTasksAndUiTaskSets do
  let(:miq_set_stub)      { migration_stub(:MiqSet) }
  let(:relationship_stub) { migration_stub(:Relationship) }

  migration_context :up do
    it "removes MiqSet instances for UiTaskSets" do
      deleted = miq_set_stub.create!(:set_type => "UiTaskSet",    :name => "super_administrator", :description => "Super Administrator")
      ignored = miq_set_stub.create!(:set_type => "MiqWidgetSet", :name => "default", :description => "Default Dashboard")

      migrate

      expect { deleted.reload }.to     raise_error(ActiveRecord::RecordNotFound)
      expect { ignored.reload }.to_not raise_error
    end

    it "removes Relationship instances for UiTaskSets" do
      deleted = relationship_stub.create!(:resource_type => "UiTaskSet",    :relationship => "membership")
      ignored = relationship_stub.create!(:resource_type => "MiqWidgetSet", :relationship => "membership")

      migrate

      expect { deleted.reload }.to     raise_error(ActiveRecord::RecordNotFound)
      expect { ignored.reload }.to_not raise_error
    end
  end
end
