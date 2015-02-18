class VmdbDatabaseSetting < ActiveRecord::Base
  self.table_name = 'pg_settings'
  self.primary_key = nil

  virtual_belongs_to :vmdb_database
  virtual_column :description,      :type => :string
  virtual_column :minimum_value,    :type => :integer
  virtual_column :maximum_value,    :type => :integer
  virtual_column :vmdb_database_id, :type => :integer

  attr_writer :vmdb_database

  def vmdb_database
    @vmdb_database ||= VmdbDatabase.my_database
  end

  def vmdb_database_id
    vmdb_database.id
  end

  def minimum_value
    min_val || ''
  end

  def maximum_value
    max_val || ''
  end

  def value
    setting || ''
  end

  def description
    desc = short_desc
    desc += "  #{extra_desc}" unless extra_desc.nil?
    desc
  end

  def unit
    super || ''
  end
end
