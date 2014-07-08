module MiqAeDatastore
  XML_VERSION = "1.0"
  XML_VERSION_MIN_SUPPORTED = "1.0"
  MANAGEIQ_DOMAIN = "ManageIQ"
  MANAGEIQ_PRIORITY = 0
  DEFAULT_OBJECT_NAMESPACE = "$"
  TEMP_DOMAIN_PREFIX = "TEMP_DOMAIN"
  ALL_DOMAINS = "*"

  # deprecated module
  module Import
    def self.load_xml(xml, domain = MiqAeDatastore.temp_domain)
      MiqAeDatastore.xml_deprecated_warning
      XmlImport.load_xml(xml, domain)
    end
  end

  TMP_DIR = File.expand_path(File.join(Rails.root, "tmp/miq_automate_engine"))

  def self.temp_domain
    "#{TEMP_DOMAIN_PREFIX}-#{MiqUUID.new_guid}"
  end

  def self.xml_deprecated_warning
    msg = "[DEPRECATION] xml export/import is deprecated. Please use the YAML format instead.  At #{caller[1]}"
    $log.warn msg
    warn msg
  end

  def self.default_backup_filename
    "datastore_#{format_timezone(Time.now, Time.zone, "fname")}.zip"
  end

  def self.backup(options)
    options['zip_file'] ||= default_backup_filename
    export_options = options.slice('zip_file', 'overwrite')
    MiqAeExport.new(ALL_DOMAINS, export_options).export
  end

  def self.convert(filename, domain_name = temp_domain, export_options = {})
    if export_options['zip_file'].blank? && export_options['export_dir'].blank? && export_options['yaml_file'].blank?
      export_options['export_dir'] = TMP_DIR
    end

    File.open(filename, 'r') do |handle|
      XmlYamlConverter.convert(handle, domain_name, export_options)
    end
  end

  def self.upload(fd, name = nil, domain_name = ALL_DOMAINS)
    name     ||= fd.original_filename
    ext        = File.extname(name)
    basename   = File.basename(name, ext)
    name       = "#{basename}.zip"
    block_size = 65_536
    FileUtils.mkdir_p(TMP_DIR) unless File.directory?(TMP_DIR)
    filename = File.join(TMP_DIR, name)

    $log.info("MIQ(MiqAeDatastore) Uploading Datastore Import to file <#{filename}>") if $log

    outfd = File.open(filename, "wb")
    data  = fd.read(block_size)
    until fd.eof
      outfd.write(data)
      data = fd.read(block_size)
    end
    outfd.write(data) if data
    fd.close
    outfd.close

    $log.info("MIQ(MiqAeDatastore) Upload complete (size=#{File.size(filename)})") if $log

    begin
      import_yaml_zip(filename, domain_name)
    ensure
      File.delete(filename)
    end
  end

  def self.import(fname, domain = temp_domain)
    _, t = Benchmark.realtime_block(:total_time) { XmlImport.load_file(fname, domain) }
    $log.info("MIQ(MiqAeDatastore.import) Import #{fname}...Complete - Benchmark: #{t.inspect}")
  end

  def self.restore(fname)
    $log.info("MIQ(MiqAeDatastore.restore) Restore from #{fname}...Starting")
    MiqAeDatastore.reset
    MiqAeImport.new(ALL_DOMAINS, 'zip_file' => fname, 'preview' => false).import
    $log.info("MIQ(MiqAeDatastore.restore) Restore from #{fname}...Complete")
  end

  def self.import_yaml_zip(fname, domain)
    t = Benchmark.realtime_block(:total_time) do
      import_options = {'zip_file' => fname, 'preview' => false, 'mode' => 'add'}
      MiqAeImport.new(domain, import_options).import
    end
    $log.info("MIQ(MiqAeDatastore.import) Import #{fname}...Complete - Benchmark: #{t.inspect}")
  end

  def self.import_yaml_dir(dirname, domain)
    t = Benchmark.realtime_block(:total_time) do
      import_options = {'import_dir' => dirname, 'preview' => false, 'mode' => 'add'}
      MiqAeImport.new(domain, import_options).import
    end
    $log.info("MIQ(MiqAeDatastore.import) Import from #{dirname}...Complete - Benchmark: #{t.inspect}")
  end

  def self.export
    require 'tempfile'
    temp_export = Tempfile.new('ae_export')
    MiqAeDatastore.backup('zip_file' => temp_export.path, 'overwrite' => true)
    File.read(temp_export.path)
  ensure
    temp_export.close
    temp_export.unlink
  end

  def self.export_class(ns, class_name)
    XmlExport.class_to_xml(ns, class_name)
  end

  def self.export_namespace(ns)
    XmlExport.namespace_to_xml(ns)
  end

  def self.reset
    $log.info("MIQ(MiqAeDatastore) Clearing datastore") if $log
    [MiqAeClass, MiqAeField, MiqAeInstance, MiqAeNamespace, MiqAeMethod, MiqAeValue].each { |k| k.delete_all }
  end

  def self.reset_default_namespace
    ns = MiqAeNamespace.find_by_fqname(DEFAULT_OBJECT_NAMESPACE)
    ns.destroy if ns
    seed_default_namespace
  end

  def self.reset_domain(datastore_dir, domain_name)
    $log.info("MIQ(MiqAeDatastore) Resetting domain #{domain_name} from #{datastore_dir}") if $log
    ns = MiqAeDomain.find_by_fqname(domain_name)
    ns.destroy if ns
    import_yaml_dir(datastore_dir, domain_name)
    if domain_name.downcase == MANAGEIQ_DOMAIN.downcase
      ns = MiqAeDomain.find_by_fqname(MANAGEIQ_DOMAIN)
      ns.update_attributes!(:system => true, :enabled => true, :priority => MANAGEIQ_PRIORITY) if ns
    end
  end

  def self.seed_default_namespace
    default_ns   = MiqAeNamespace.create!(:name => DEFAULT_OBJECT_NAMESPACE)
    object_class = default_ns.ae_classes.create!(:name => 'Object')

    default_method_options = {:language => 'ruby', :scope => 'instance', :location => 'builtin'}
    object_class.ae_methods.create!(default_method_options.merge(:name => 'log_object'))
    object_class.ae_methods.create!(default_method_options.merge(:name => 'log_workspace'))

    email_method = object_class.ae_methods.create!(default_method_options.merge(:name => 'send_email'))
    email_method.inputs.create!([{:name => 'to',      :priority => 1, :datatype => 'string'},
                                 {:name => 'from',    :priority => 2, :datatype => 'string'},
                                 {:name => 'subject', :priority => 3, :datatype => 'string'},
                                 {:name => 'body',    :priority => 4, :datatype => 'string'}])
  end

  def self.reset_to_defaults
    ds_dir = File.expand_path(File.join(Rails.root, 'db/fixtures/ae_datastore'))
    raise "Datastore directory [#{ds_dir}] not found" unless Dir.exist?(ds_dir)
    Dir.glob("#{ds_dir}/*/#{MiqAeDomain::DOMAIN_YAML_FILENAME}").each do |domain_file|
      domain_name = File.basename(File.dirname(domain_file))
      reset_domain(ds_dir, domain_name)
    end
    reset_default_namespace
  end

  def self.seed
    MiqRegion.my_region.lock(:shared, 1800) do
      log_prefix = 'MIQ(MiqAeDatastore.seed)'
      ns = MiqAeDomain.find_by_fqname(MANAGEIQ_DOMAIN)
      unless ns
        $log.info "#{log_prefix} Seeding ManageIQ domain..." if $log
        begin
          reset_to_defaults
        rescue => err
          $log.error "#{log_prefix} Seeding... Reset failed, #{err.message}" if $log
        else
          $log.info "#{log_prefix} Seeding... Complete" if $log
        end
      end
    end
  end
end # module MiqAeDatastore
