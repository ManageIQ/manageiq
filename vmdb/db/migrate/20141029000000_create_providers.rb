class CreateProviders < ActiveRecord::Migration
  def up
    create_table :providers do |t|
      t.string     :type
      t.string     :name
      t.string     :url
      t.integer    :verify_ssl
      t.string     :guid, :limit => 36
      t.belongs_to :zone, :type  => :bigint
      t.timestamps
    end
  end

  def down
    drop_table :providers
  end
end
