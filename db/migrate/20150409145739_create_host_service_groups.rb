class CreateHostServiceGroups < ActiveRecord::Migration[4.2]
  def up
    create_table :host_service_groups do |t|
      t.string     :name
      t.string     :type
      t.belongs_to :host, :type => :bigint
    end
  end

  def down
    drop_table :host_service_groups
  end
end
