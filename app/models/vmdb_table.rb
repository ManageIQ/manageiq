class VmdbTable < ApplicationRecord
  belongs_to :vmdb_database

  has_many :vmdb_indexes,                            :dependent => :destroy
  has_many :vmdb_metrics,          :as => :resource  # Destroy will be handled by purger

  has_one  :latest_hourly_metric,  -> { VmdbMetric.where(:capture_interval_name => 'hourly', :resource_type => 'VmdbTable', :timestamp => VmdbMetric.maximum(:timestamp)) }, :as => :resource, :class_name => 'VmdbMetric'

  # index_name1,unique1,col11,col12|index_name2,unique2,col21,col22
  virtual_attribute :all_indexes, :string, :arel => (lambda do |t|
    t.grouping(
      Arel::Nodes::SqlLiteral.new(
        "SELECT
           string_agg(
           distinct ix.relname || ',' || indisunique || ',' ||
          regexp_replace(pg_get_indexdef(indexrelid), '^[^\\)]*\\(([^\\)]*)\\).*$', '\\1'), '|')
        FROM pg_class t
        INNER JOIN pg_index i ON t.oid = i.indrelid
        INNER JOIN pg_class ix ON ix.oid = i.indexrelid
        WHERE t.relname = #{t.name}.name"
      )
    )
    # if we want only the primary index, add "AND i.indisprimary"
  end)

  # viable for vmdb_table_evm - defined in vmdb_table to make query from base class work
  virtual_attribute :actual_text_tables, :string, :arel => (lambda do |t|
    t.grouping(
      Arel::Nodes::SqlLiteral.new(
        "SELECT string_agg(pg_class.relname, ',')
        FROM pg_class JOIN pg_class pg_class2 ON pg_class.oid = pg_class2.reltoastrelid
        WHERE pg_class2.relname = #{t.name}.name
        GROUP BY pg_class2.relname"
      )
    )
  end)

  include VmdbDatabaseMetricsMixin

  include_concern 'Seeding'

  serialize :prior_raw_metrics

  def my_metrics
    vmdb_metrics
  end

  def self.display_name(number = 1)
    n_('Table', 'Tables', number)
  end

  def sql_indexes
    if has_attribute?(:all_indexes)
      self["all_indexes"].split("|").map do |indx|
        index_name, unique, *columns = indx.split(",")
        ActiveRecord::ConnectionAdapters::IndexDefinition.new(name, index_name, unique == 't', columns.map(&:strip))
      end
    else
      self.class.connection.indexes(name) << self.class.connection.primary_key_index(name)
      # ALT: self.class.connection.all_indexes(name)
    end
  end

  def actual_text_tables
    return self["actual_text_tables"]&.split(",") || [] if has_attribute?(:actual_text_tables)
    self.class.connection.respond_to?(:text_tables) ? self.class.connection.text_tables(name) : []
  end
end
