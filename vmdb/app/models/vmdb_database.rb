class VmdbDatabase < ActiveRecord::Base
  has_many :vmdb_tables,           :dependent => :destroy
  has_many :evm_tables,            :class_name => 'VmdbTableEvm'
  has_many :vmdb_database_metrics, :dependent => :destroy
  has_one  :latest_hourly_metric,  :class_name => 'VmdbDatabaseMetric', :conditions => {:capture_interval_name => 'hourly'}, :order => "timestamp DESC"

  virtual_has_many :vmdb_database_settings
  virtual_has_many :vmdb_database_connections

  include ReportableMixin
  include VmdbDatabaseMetricsMixin

  include_concern 'VmdbDatabase::MetricCapture'
  include_concern 'Logging'
  include_concern 'Seeding'

  def vmdb_database_settings
    self.in_current_region? ? VmdbDatabaseSetting.all : []
  end

  def vmdb_database_connections
    self.in_current_region? ? VmdbDatabaseConnection.all : []
  end

  def self.my_database
    VmdbDatabase.in_my_region.first
  end

  def my_metrics
    self.vmdb_database_metrics
  end

  def size_postgresql
    self.class.connection.select_value("SELECT pg_database_size('#{self.name}')").to_i
  end

  def size
    adapter = self.class.connection.adapter_name.downcase
    case adapter
    when "postgres", "postgresql"; size_postgresql
    else
       raise "#{adapter} is not supported"
    end
  end

  def top_tables_by(sorted_by, limit = nil)
    # latest_hourly_metric via includes causes too many rows to come back.
    #   Instead we will manually query for the MAX(id), which is simpler than
    #   MAX(timestamp).
    table_ids  = self.evm_tables.collect(&:id)
    latest_ids = VmdbMetric.where(:resource_type => "VmdbTable", :resource_id => table_ids, :capture_interval_name => "hourly").select("MAX(id) AS id").group(:resource_type, :resource_id).collect(&:id)
    metrics    = VmdbMetric.where(:id => latest_ids).all

    metrics = metrics.sort_by { |m| m.send(sorted_by) }.reverse
    metrics = metrics[0, limit] if limit.kind_of?(Numeric)

    tables_by_id = self.evm_tables.index_by(&:id)
    metrics.collect { |m| tables_by_id[m.resource_id] }
  end


  #
  # Report database statistics and bloat...
  #

  def self.report_table_bloat
    connection.table_bloat if connection.respond_to?(:table_bloat)
  end

  def self.report_index_bloat
    connection.index_bloat if connection.respond_to?(:index_bloat)
  end

  def self.report_database_bloat
    connection.database_bloat if connection.respond_to?(:database_bloat)
  end

  def self.report_table_statistics
    connection.table_statistics if connection.respond_to?(:table_statistics)
  end

  def self.report_table_size
    connection.table_size if connection.respond_to?(:table_size)
  end

  def self.report_client_connections
    connection.client_connections if connection.respond_to?(:client_connections)
  end

end
