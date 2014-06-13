class AddMiqTaskIdAndLastGeneratedContentOnToMiqWidgets < ActiveRecord::Migration
  class MiqWidget < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def self.up
    add_column :miq_widgets, :last_generated_content_on, :timestamp
    add_column :miq_widgets, :miq_task_id,               :bigint

    say_with_time("Migrate data from reserved table") do
      MiqWidget.includes(:reserved_rec).each do |w|
        w.reserved_hash_migrate(:miq_task_id, :last_generated_content_on)
      end
    end

  end

  def self.down
    remove_column :miq_widgets, :last_generated_content_on
    remove_column :miq_widgets, :miq_task_id
  end
end
