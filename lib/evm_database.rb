class EvmDatabase
  include Vmdb::Logging

  PRIMORDIAL_CLASSES = %w(
    MiqDatabase
    MiqRegion
    MiqEnterprise
    Zone
    MiqServer
    ServerRole
    Tenant
    MiqProductFeature
    MiqUserRole
    MiqGroup
    User
    MiqReport
    VmdbDatabase
  )

  ORDERED_CLASSES = %w(
    RssFeed
    MiqWidget
  )

  RAILS_ENGINE_MODEL_CLASS_NAMES = %w(MiqAeDatastore)

  def self.find_seedable_model_class_names
    @found_model_class_names ||= begin
      Dir.glob(Rails.root.join("app/models/*.rb")).collect { |f| File.basename(f, ".*").camelize if File.read(f).include?("self.seed") }.compact.sort
    end
  end

  def self.seedable_model_class_names
    ORDERED_CLASSES + (find_seedable_model_class_names - ORDERED_CLASSES) + RAILS_ENGINE_MODEL_CLASS_NAMES
  end

  def self.seed_primordial
    if ENV['SKIP_PRIMORDIAL_SEED'] && MiqDatabase.count > 0
      puts "** Primordial seedings is skipped."
      puts "** Unset SKIP_PRIMORDIAL_SEED to re-enable"
    else
      seed(PRIMORDIAL_CLASSES)
    end
  end

  def self.seed_last
    seed(seedable_model_class_names - PRIMORDIAL_CLASSES)
  end

  def self.seed(classes = nil, exclude_list = [])
    _log.info("Seeding...")

    classes ||= PRIMORDIAL_CLASSES + (seedable_model_class_names - PRIMORDIAL_CLASSES)
    classes -= exclude_list

    # Only 1 machine can go through this at a time
    # Populating the DB takes 20 seconds
    # Not populating the db takes 3 seconds
    MiqDatabase.with_lock(10.minutes) do
      classes.each do |klass|
        begin
          klass = klass.constantize if klass.kind_of?(String)
        rescue => err
          _log.log_backtrace(err)
          raise
        end

        if klass.respond_to?(:seed)
          _log.info("Seeding #{klass}")
          begin
            klass.seed
          rescue => err
            _log.log_backtrace(err)
            raise
          end
        else
          _log.error("Class #{klass} does not have a seed")
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
