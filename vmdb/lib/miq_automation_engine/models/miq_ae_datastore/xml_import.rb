module MiqAeDatastore
  class XmlImport
    def self.process_class(input)
      fields    = input.delete("MiqAeSchema")
      instances = input.delete("MiqAeInstance")
      methods   = input.delete("MiqAeMethod")

      # Create the AEClass
      aec       = MiqAeClass.new(input)

      Benchmark.realtime_block(:process_class_schema_time) do
        # Find or Create the AEFields
        unless fields.nil?
          aec.ae_fields = process_fields(fields)
          unless instances.nil?
            aec.ae_instances = instances.collect { |i| process_instance(i, aec) }
          end
        end
      end

      Benchmark.realtime_block(:process_class_methods_time) do
        unless methods.nil?
          aec.ae_methods = methods.collect { |m| process_method(m) }
        end
      end

      Benchmark.realtime_block(:process_class_save_time) do
        $log.info("MiqAeDatastore: Importing Class: #{aec.fqname}") if $log
        aec.save!
      end
    end

    def self.process_method(input)
      fields             = input.delete("MiqAeField")
      input["data"]      = input.delete("content")
      input["data"].strip! unless input["data"].nil?
      aem                = MiqAeMethod.new(input)

      # Find or Create the Method Input Definitions
      aem.inputs = process_method_inputs(fields)        unless fields.nil?
      aem
    end

    def self.process_method_inputs(fields)
      priority = 0
      inputs = []
      fields.each do |f|
        priority += 1
        f["priority"] = priority unless f.include?("priority")
        default_value = f.delete("content")
        f["default_value"] = default_value.strip unless f.key?("default_value") || default_value.nil?
        inputs << MiqAeField.new(f)
      end
      inputs
    end

    def self.process_fields(fields)
      priority = 0
      ae_fields = []
      fields.each do |field|
        field["MiqAeField"].each do |f|
          priority += 1
          f["message"]    ||= MiqAeField.default('message')
          f["priority"]   ||= priority
          f['substitute'] = MiqAeField.default('substitute') unless %w(true false).include?(f['substitute'])
          f['substitute'] = true  if f['substitute'] == 'true'
          f['substitute'] = false if f['substitute'] == 'false'
          default_value = f.delete("content")
          f["default_value"] = default_value.strip unless f.key?("default_value") || default_value.nil?

          unless f["collect"].blank?
            f["collect"] = f["collect"].first["content"]            if f["collect"].kind_of?(Array)
            f["collect"] = REXML::Text.unnormalize(f["collect"].strip)
          end

          %w(on_entry on_exit on_error max_retries max_time).each do |k|
            f[k] = REXML::Text.unnormalize(f[k].strip) unless f[k].blank?
          end

          ae_fields << MiqAeField.new(f)
        end
      end
      ae_fields
    end

    def self.process_instance(input, aec)
      fields = input.delete("MiqAeField")
      input.delete("content")
      aei = MiqAeInstance.new(input)
      aei.ae_class = aec
      fields.each { |f| process_field_value(aei, f) } unless fields.nil?
      aei
    end

    def self.process_field_value(aei, field)
      options = {}
      fname = field["name"]
      ae_field = aei.ae_class.ae_fields.detect { |f| fname.casecmp(f.name) == 0 }
      raise MiqAeException::FieldNotFound, "Field [#{fname}] not found in MiqAeDatastore" if ae_field.nil?
      options[:ae_field] = ae_field
      value = field["value"] || field["content"]
      value.strip! unless value.blank?
      options[:value]    = value
      %w(collect on_entry on_exit on_error max_retries max_time).each do |key|
        next if field[key].blank?
        options[key.to_sym] = REXML::Text.unnormalize(field[key].strip)
      end
      aei.ae_values << MiqAeValue.new(options)
    end

    def self.process_button(input)
      puts "Button Input: #{input.inspect}"
      CustomButton.create_or_update_from_hash(input)
    end

    def self.check_version(v)
      v.to_s >= MiqAeDatastore::XML_VERSION_MIN_SUPPORTED
    end

    $:.push File.expand_path(File.join(Rails.root, %w(.. lib util xml)))
    def self.load_xml(f, domain_name = nil)
      _, t = Benchmark.realtime_block(:total_load_xml_time) do
        classes = buttons = nil
        Benchmark.realtime_block(:xml_load_time) do
          require 'xml_hash'
          doc = XmlHash.load(f)
          version = doc.children[0].attributes[:version]
          $log.info("MIQ(MiqAeDatastore)   with version '#{version}'") if $log
          raise "Unsupported version '#{version}'.  Must be at least '#{MiqAeDatastore::XML_VERSION_MIN_SUPPORTED}'." unless check_version(version)
          classes = doc.to_h(:symbols => false)["MiqAeClass"]
          buttons = doc.to_h(:symbols => false)["MiqAeButton"]
        end

        create_domain(domain_name) if domain_name
        ae_namespaces = Hash.new
        Benchmark.realtime_block(:datastore_import_time) do
          classes.each do |c|
            namespace = c.delete("namespace")
            next if namespace == '$'
            namespace = File.join(domain_name, namespace) if domain_name && namespace != "$"
            ae_namespaces[namespace] ||= Benchmark.realtime_block(:build_namespaces) do
              MiqAeNamespace.find_or_create_by_fqname(namespace)
            end.first
            c["ae_namespace"] = ae_namespaces[namespace]
            process_class(c)
          end unless classes.nil?

          buttons.each { |b| process_button(b) } unless buttons.nil?
        end
      end

      $log.info("Automate Datastore Import complete: #{t.inspect}") if $log
    end

    def self.create_domain(domain)
      ns = MiqAeNamespace.find_by_fqname(domain)
      MiqAeNamespace.create!(:name => domain, :enabled => true, :priority => 100) unless ns
    end

    def self.load_xml_file(filename, domain)
      File.open(filename, 'r') { |handle| load_xml(handle, domain) }
    end

    def self.load_file(f, domain)
      $log.info("MIQ(MiqAeDatastore) Importing file '#{f}'") if $log
      ext = File.extname(f).downcase
      case ext
      when ".xml"          then load_xml_file(f, domain)
      else raise "Unhandled File Extension [#{ext}] when trying to load #{f}"
      end
      $log.info("MIQ(MiqAeDatastore) Import complete") if $log
    end
  end
end
