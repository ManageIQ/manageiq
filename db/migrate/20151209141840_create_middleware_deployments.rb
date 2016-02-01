class CreateMiddlewareDeployments < ActiveRecord::Migration
  def change
    create_table :middleware_deployments do |t|
      t.string :name # name of the deployment
      t.string :ems_ref # path
      t.string :nativeid
      t.bigint :server_id
      t.bigint :ems_id

      t.timestamps :null => false
    end
  end
end
