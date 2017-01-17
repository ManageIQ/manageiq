class CreateDatawarehouseNode < ActiveRecord::Migration[5.0]
  def change
    create_table :datawarehouse_nodes do |t|
      t.string     :ems_ref
      t.string     :name

      t.string     :host
      t.string     :ip
      t.string     :port

      t.boolean    :master
      t.float      :load
      t.float      :mem
      t.float      :heap
      t.float      :disk
      t.float      :cpu

      t.belongs_to :ems, :type => :bigint
    end
  end
end
