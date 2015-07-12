class CreateContainerEnvVars < ActiveRecord::Migration
  def up
    create_table :container_env_vars do |t|
      t.string     :name
      t.text       :value
      t.string     :field_path
      t.belongs_to :container_definition, :type => :bigint
    end
  end

  def down
    drop_table :container_env_vars
  end
end
