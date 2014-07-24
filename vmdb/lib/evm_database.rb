class EvmDatabase

  PRIMORDIAL_CLASSES = %w{
    MiqDatabase
    MiqRegion
    MiqEnterprise
    Zone
    MiqServer
    ServerRole
    MiqProductFeature
    MiqUserRole
    MiqGroup
    User
    MiqReport
    RssFeed
    MiqWidget
    VmdbDatabase
  }

  def self.model_class_names
    @model_class_names ||= begin
      Dir.glob(File.join(Rails.root, "app/models/*.rb")).collect { |f| File.basename(f, ".*").camelize }.compact.sort
    end
  end

  def self.seed_primordial
    self.seed(PRIMORDIAL_CLASSES)
  end

  def self.seed_last
    self.seed(model_class_names - PRIMORDIAL_CLASSES)
  end

  def self.seed(classes = nil, exclude_list = [])
    log_prefix = "EvmDatabase.seed"
    $log.info("#{log_prefix} Seeding...") if $log

    classes ||= PRIMORDIAL_CLASSES + (model_class_names - PRIMORDIAL_CLASSES)
    classes  -= exclude_list

    classes.each do |klass|
      begin
        klass = klass.constantize if klass.kind_of?(String)
      rescue
        $log.error("#{log_prefix} Class #{klass.to_s} does not exist") if $log
        next
      end

      if klass.respond_to?(:seed)
        $log.info("#{log_prefix} Seeding #{klass.to_s}") if $log
        begin
          klass.seed
        rescue => err
          $log.log_backtrace(err) if $log
        end
      end
    end

    $log.info("#{log_prefix} Seeding... Complete") if $log
  end

  def self.host
    Rails.configuration.database_configuration[Rails.env]['host']
  end

  def self.local?
    ["localhost", "localhost.localdomain", "127.0.0.1", "0.0.0.0"].include?(self.host)
  end

  # Determines the average time to the database in milliseconds
  def self.ping(connection)
    query = "SELECT 1"
    query << " FROM DUAL" if connection.class.name == "OracleAdapter" || connection.class.name == "OracleEnhancedAdapter"
    Benchmark.realtime { 10.times { connection.select_value(query) } } / 10 * 1000
  end

  # Legacy method for destroying database content:
  # Instead use rake evm:db:destroy which drops and recreates the database.
  def self.destroy
    ActiveRecord::Base.connection.views.each  {|v| ActiveRecord::Schema.define { drop_view  v.to_sym, :force => true } rescue nil}
    ActiveRecord::Base.connection.tables.each {|t| ActiveRecord::Schema.define { drop_table t.to_sym, :force => true } rescue nil}
    ActiveRecord::Base.connection_handler.clear_all_connections!
  end
end
