class AddReservedToMiqAeMethods < ActiveRecord::Migration
  def self.up
    add_column    :miq_ae_methods, :reserved, :text
  end

  def self.down
    remove_column :miq_ae_methods, :reserved
  end
end
