class CreateSecurityGroups < ActiveRecord::Migration
  def change
    create_table :security_groups do |t|
      t.string     :name
      t.string     :description
      t.string     :type
      t.belongs_to :ems, :type => :bigint
      t.string     :ems_ref
    end
  end
end
