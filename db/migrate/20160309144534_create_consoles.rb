class CreateConsoles < ActiveRecord::Migration[5.0]
  def change
    create_table :consoles do |t|
      t.string :protocol
      t.string :host_name
      t.integer :port
      t.boolean :ssl
      t.string :secret
      t.references :vm,   :foreign_key => true
      t.references :user, :foreign_key => true
      t.string :url_secret

      t.timestamps
    end

    add_index :consoles, :url_secret, :unique => true
  end
end
