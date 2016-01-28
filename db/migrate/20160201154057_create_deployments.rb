class CreateDeployments < ActiveRecord::Migration
  def change
    create_table :deployments do |t|
      t.timestamps :null => false
    end
  end
end
