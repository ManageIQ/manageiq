class FixBooleanColumnsInClassifications < ActiveRecord::Migration
  class Classification < ActiveRecord::Base; end

  def self.up
    change_column :classifications, :read_only,    :boolean, :cast_as => :boolean
    change_column :classifications, :default,      :boolean, :cast_as => :boolean
    change_column :classifications, :single_value, :boolean, :cast_as => :boolean
  end

  def self.down
    change_column :classifications, :read_only,    :string, :cast_as => :string
    change_column :classifications, :default,      :string, :cast_as => :string
    change_column :classifications, :single_value, :string, :cast_as => :string
  end
end
