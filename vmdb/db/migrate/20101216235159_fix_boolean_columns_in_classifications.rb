class FixBooleanColumnsInClassifications < ActiveRecord::Migration
  class Classification < ActiveRecord::Base; end

  def self.up
    # Fix issue where older code is placing hard "t" values when in SQL Server,
    #   which causes change_column to boolean to fail.
    if connection.adapter_name == "SQLServer"
      say_with_time("Fix invalid data") do
        expected = ["1", "0", nil]
        true_values = ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES

        Classification.all.each do |c|
          c.read_only    = true_values.include?(c.read_only)    unless expected.include?(c.read_only)
          c.default      = true_values.include?(c.default)      unless expected.include?(c.default)
          c.single_value = true_values.include?(c.single_value) unless expected.include?(c.single_value)
          c.save!
        end
      end
    end

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
