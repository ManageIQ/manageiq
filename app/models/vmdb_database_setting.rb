class VmdbDatabaseSetting < ApplicationRecord
  self.table_name = 'pg_catalog.pg_settings'
  self.primary_key = 'name'

  virtual_belongs_to :vmdb_database
  virtual_column :description,      :type => :string
  virtual_column :vmdb_database_id, :type => :integer

  attr_writer :vmdb_database

  def vmdb_database
    @vmdb_database ||= VmdbDatabase.my_database
  end

  delegate :id, :to => :vmdb_database, :prefix => true

  alias_attribute :minimum_value, :min_val
  alias_attribute :maximum_value, :max_val
  alias_attribute :value, :setting

  def description
    desc = short_desc
    desc += "  #{extra_desc}" unless extra_desc.nil?
    desc
  end

  def self.display_name(number = 1)
    n_('Database Setting', 'Database Settings', number)
  end
end
