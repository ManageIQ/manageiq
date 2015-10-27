class CreateContainerComponentStatuses < ActiveRecord::Migration
  def up
    create_table :container_component_statuses do |t|
      t.belongs_to :ems, :type => :bigint
      t.string     :name
      t.string     :condition
      t.string     :status
      t.string     :message
      t.string     :error
    end
  end

  def down
    drop_table :container_component_statuses
  end
end
