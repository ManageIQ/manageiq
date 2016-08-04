class CreateMiddlewareDomains < ActiveRecord::Migration[5.0]
  def change
    create_table :middleware_domains do |t|
      t.string :name # name of the domain
      t.string :ems_ref # path
      t.string :nativeid
      t.string :feed
      t.string :type_path
      t.string :profile
      t.text   :properties
      t.bigint :ems_id

      t.timestamps :null => false
    end
  end
end
