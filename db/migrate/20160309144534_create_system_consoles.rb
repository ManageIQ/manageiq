class CreateSystemConsoles < ActiveRecord::Migration[5.0]
  def change
    create_table :system_consoles do |t|
      t.string     :url_secret
      t.string     :host_name
      t.integer    :port
      t.boolean    :ssl
      t.string     :protocol
      t.string     :secret
      t.boolean    :opened
      t.belongs_to :vm,   :type => :bigint
      t.belongs_to :user, :type => :bigint

      t.timestamps
    end

    add_index :system_consoles, :url_secret, :unique => true
  end
end
