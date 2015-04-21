class EvmDatabase
  include Vmdb::NewLogging

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

  def self.seedable_model_class_names
    @seedable_model_class_names ||= begin
      Dir.glob(Rails.root.join("app/models/*.rb")).collect { |f| File.basename(f, ".*").camelize if File.read(f).include?("self.seed") }.compact.sort
    end
  end

  def self.seed_primordial
    self.seed(PRIMORDIAL_CLASSES)
  end

  def self.seed_last
    self.seed(seedable_model_class_names - PRIMORDIAL_CLASSES)
  end

  def self.seed(classes = nil, exclude_list = [])
    _log.info("Seeding...")

    classes ||= PRIMORDIAL_CLASSES + (seedable_model_class_names - PRIMORDIAL_CLASSES)
    classes  -= exclude_list

    classes.each do |klass|
      begin
        klass = klass.constantize if klass.kind_of?(String)
      rescue
        _log.error("Class #{klass} does not exist")
        next
      end

      if klass.respond_to?(:seed)
        _log.info("Seeding #{klass}")
        begin
          klass.seed
        rescue => err
          _log.log_backtrace(err)
        end
      end
    end

    _log.info("Seeding... Complete")
  end

  def self.host
    Rails.configuration.database_configuration[Rails.env]['host']
  end

  def self.local?
    host.blank? || ["localhost", "localhost.localdomain", "127.0.0.1", "0.0.0.0"].include?(host)
  end

  # Determines the average time to the database in milliseconds
  def self.ping(connection)
    query = "SELECT 1"
    Benchmark.realtime { 10.times { connection.select_value(query) } } / 10 * 1000
  end
end
