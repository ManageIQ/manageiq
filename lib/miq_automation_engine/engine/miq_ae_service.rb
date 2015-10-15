module MiqAeMethodService
  class MiqAeServiceFront
    include DRbUndumped
    def find(id)
      MiqAeService.find(id)
    end
  end

  class MiqAeService
    include Vmdb::Logging
    include DRbUndumped
    @@id_hash = {}
    @@current = []

    def self.current
      @@current.last
    end

    def self.find(id)
      @@id_hash[id.to_i]
    end

    def self.add(obj)
      @@id_hash[obj.object_id] = obj
      @@current << obj
    end

    def self.destroy(obj)
      @@id_hash.delete(obj.object_id)
      @@current.delete(obj)
    end

    def initialize(ws)
      @drb_server_references = []
      @inputs                = {}
      @workspace             = ws
      @preamble_lines        = 0
      @body                  = []
      @persist_state_hash    = ws.persist_state_hash
      self.class.add(self)
    end

    def destroy
      self.class.destroy(self)
    end

    def body=(data)
      @body_raw = data
      @body     = begin
        lines = []
        @body_raw.each_line { |l| lines << l.rstrip }
        lines
      end
    end

    def body
      @body_raw
    end

    def preamble
      @preamble_raw
    end

    def preamble=(data)
      @preamble_raw = data
      @preamble = begin
        lines = []
        @preamble_raw.each_line { |l| lines << l.rstrip }
        lines
      end
      @preamble_lines = @preamble.length
    end

    def method_body(options = {})
      if options[:line_numbers]
        line_number = 0
        @body.collect do |line|
          line_number += 1
          "#{format "%03d" % line_number}: #{line}"
        end
      else
        @body
      end
    end

    def backtrace(callers)
      return callers unless callers.respond_to?(:collect)

      callers.collect do |c|
        file, line, context = c.split(':')
        if file == "-"
          line_adjusted_for_preamble = line.to_i - @preamble_lines
          file = @body[line_adjusted_for_preamble - 1].to_s.strip
          "<code: #{file}>:#{line_adjusted_for_preamble}:#{context}"
        else
          c
        end
      end
    end

    def disconnect_sql
      ActiveRecord::Base.connection_pool.release_connection
    end

    attr_writer :inputs

    attr_reader :inputs

    ####################################################

    def log(level, msg)
      $miq_ae_logger.send(level, "<AEMethod #{current_method}> #{msg}")
    end

    def set_state_var(name, value)
      @persist_state_hash[name] = value
    end

    def state_var_exist?(name)
      @persist_state_hash.key?(name)
    end

    def get_state_var(name)
      @persist_state_hash[name]
    end

    def instantiate(uri)
      obj = @workspace.instantiate(uri, @workspace.ae_user, @workspace.current_object)
      return nil if obj.nil?
      drb_return(MiqAeServiceObject.new(obj, self))
    rescue => e
      return nil
    end

    def drb_return(obj)
      # Save a reference to the object, so that we control when it gets deleted.  Otherwise, Ruby Garbage Collection may remove it prematurely.
      # If it is removed prematurely and then referenced by the method, we get a DRb recycled object error
      @drb_server_references << obj
      obj
    end

    def object(path = nil)
      obj = @workspace.get_obj_from_path(path)
      return nil if obj.nil?
      drb_return MiqAeServiceObject.new(obj, self)
    end

    def hash_to_query(hash)
      MiqAeEngine::MiqAeUri.hash2query(hash)
    end

    def query_to_hash(query)
      MiqAeEngine::MiqAeUri.query2hash(query)
    end

    def current_namespace
      @workspace.current_namespace
    end

    def current_class
      @workspace.current_class
    end

    def current_instance
      @workspace.current_instance
    end

    def current_message
      @workspace.current_message
    end

    def current_object
      @current_object ||= drb_return(MiqAeServiceObject.new(@workspace.current_object, self))
    end

    def current_method
      @workspace.current_method
    end

    def current
      current_object
    end

    def root
      @root_object ||= object("/")
    end

    def parent
      @parent_object ||= object("..")
    end

    def objects(aobj)
      aobj.collect do |obj|
        obj = drb_return(MiqAeServiceObject.new(obj, self)) unless obj.kind_of?(MiqAeServiceObject)
        obj
      end
    end

    def vmdb(type, *args)
      type = type.to_s.underscore
      type = "ext_management_system" if type == "ems"
      service = MiqAeMethodService.const_get("MiqAeService#{type.camelize}")
      args.empty? ? service : service.find(*args)
    end

    def datastore
    end

    def ldap
    end

    CUSTOMER_ROOT = File.expand_path(File.join(Rails.root, "..", "customer"))
    $:.push CUSTOMER_ROOT
    def new_object(what, *args)
      begin
        require what.underscore
      rescue LoadError => err
        _log.warn("Error requiring <#{what}> from #{CUSTOMER_ROOT} because <#{err.message}>")
        return nil
      end

      begin
        klass = what.constantize
      rescue NameError => err
        _log.warn("Error converting <#{what}> to a constant because <#{err.message}>")
        ruby_file = File.join(CUSTOMER_ROOT, "#{what.underscore}.rb")
        contents  = File.read(ruby_file) rescue nil
        _log.warn("Contents of Customer Library <#{ruby_file}> are:\n#{contents}")
        return nil
      end

      klass.send(:include, DRbUndumped) unless klass.ancestors.include?(DRbUndumped)
      drb_return klass.new(*args)
    end

    def execute(m, *args)
      drb_return MiqAeServiceMethods.send(m, *args)
    rescue NoMethodError => err
      raise MiqAeException::MethodNotFound, err.message
    end

    def instance_exists?(path)
      _log.info "<< path=#{path.inspect}"
      __find_instance_from_path(path) ? true : false
    end

    def instance_create(path, values_hash = {})
      _log.info "<< path=#{path.inspect}, values_hash=#{values_hash.inspect}"

      return false unless editable_instance?(path)

      ns, klass, instance = MiqAeEngine::MiqAePath.split(path)
      $log.info("Instance Create for ns: #{ns} class #{klass} instance: #{instance}")

      aec = MiqAeClass.find_by_namespace_and_name(ns, klass)
      return false if aec.nil?

      aei = aec.ae_instances.detect { |i| instance.casecmp(i.name) == 0 }
      return false unless aei.nil?

      aei = MiqAeInstance.create(:name => instance, :class_id => aec.id)
      values_hash.each { |key, value| aei.set_field_value(key, value) }

      true
    end

    def instance_get_display_name(path)
      _log.info "<< path=#{path.inspect}"
      aei = __find_instance_from_path(path)
      aei ? aei.display_name : nil
    end

    def instance_set_display_name(path, display_name)
      _log.info "<< path=#{path.inspect}, display_name=#{display_name.inspect}"
      aei = __find_instance_from_path(path)
      return false if aei.nil?

      aei.update_attributes(:display_name => display_name)
      true
    end

    def instance_update(path, values_hash)
      _log.info "<< path=#{path.inspect}, values_hash=#{values_hash.inspect}"
      return false unless editable_instance?(path)

      aei = __find_instance_from_path(path)
      return false if aei.nil?

      values_hash.each { |key, value| aei.set_field_value(key, value) }
      true
    end

    def instance_find(path, options = {})
      _log.info "<< path=#{path.inspect}"
      result = {}

      ns, klass, instance = MiqAeEngine::MiqAePath.split(path)
      aec = MiqAeClass.find_by_namespace_and_name(ns, klass)
      unless aec.nil?
        instance.gsub!(".", '\.')
        instance.gsub!("*", ".*")
        instance.gsub!("?", ".{1}")
        instance_re = Regexp.new("^#{instance}$", Regexp::IGNORECASE)

        aec.ae_instances.select { |i| instance_re =~ i.name }.each do |aei|
          iname = if options[:path]
                    aei.fqname
                  else
                    aei.name
                  end
          result[iname] = aei.field_attributes
        end
      end

      result
    end

    def instance_get(path)
      _log.info "<< path=#{path.inspect}"
      aei = __find_instance_from_path(path)
      return nil if aei.nil?

      aei.field_attributes
    end

    def instance_delete(path)
      _log.info "<< path=#{path.inspect}"
      return false unless editable_instance?(path)

      aei = __find_instance_from_path(path)
      return false if aei.nil?

      aei.destroy
      true
    end

    def __find_instance_from_path(path)
      dom, ns, klass, instance = MiqAeEngine::MiqAePath.get_domain_ns_klass_inst(path)
      return false unless visible_domain?(dom)

      aec = MiqAeClass.find_by_namespace_and_name("#{dom}/#{ns}", klass)
      return nil if aec.nil?

      aec.ae_instances.detect { |i| instance.casecmp(i.name) == 0 }
    end

    private

    def editable_instance?(path)
      dom, = MiqAeEngine::MiqAePath.get_domain_ns_klass_inst(path)
      return false unless owned_domain?(dom)
      domain = MiqAeDomain.find_by_fqname(dom, false)
      return false unless domain
      $log.warn "path=#{path.inspect} : is not editable" unless domain.editable?
      domain.editable?
    end

    def owned_domain?(dom)
      domains = @workspace.ae_user.current_tenant.ae_domains.collect(&:name).map(&:upcase)
      return true if domains.include?(dom.upcase)
      $log.warn "domain=#{dom} : is not editable"
      false
    end

    def visible_domain?(dom)
      domains = @workspace.ae_user.current_tenant.visible_domains.collect(&:name).map(&:upcase)
      return true if domains.include?(dom.upcase)
      $log.warn "domain=#{dom} : is not viewable"
      false
    end
  end

  module MiqAeServiceObjectCommon
    def attributes
      @object.attributes.each_with_object({}) do |(key, value), hash|
        hash[key] = value.kind_of?(MiqAePassword) ? value.to_s : value
      end
    end

    def attributes=(hash)
      @object.attributes = hash
    end

    def [](attr)
      value = @object[attr.downcase]
      value = value.to_s if value.kind_of?(MiqAePassword)
      value
    end

    def []=(attr, value)
      @object[attr.downcase] = value
    end

    # To explicitly override Object#id method, which is spewing deprecation warnings to use Object#object_id
    def id
      @object ? @object.id : nil
    end

    def decrypt(attr)
      MiqAePassword.decrypt_if_password(@object[attr.downcase])
    end

    def current_field_name
      @object.current_field_name
    end

    def current_field_type
      @object.current_field_type
    end

    def current_message
      @object.current_message
    end

    def namespace
      @object.namespace
    end

    def class_name
      @object.klass
    end

    def instance_name
      @object.instance
    end

    def name
      @object.object_name
    end
  end

  class MiqAeServiceObject
    include MiqAeServiceObjectCommon
    include DRbUndumped

    def initialize(obj, svc)
      raise "object cannot be nil" if obj.nil?
      @object  = obj
      @service = svc
    end

    def children(name = nil)
      objs = @object.children(name)
      return nil if objs.nil?
      objs = @service.objects([objs].flatten)
      objs.length == 1 ? objs.first : objs
    end

    def to_s
      name
    end

    def inspect
      hex_id = (object_id << 1).to_s(16).rjust(14, '0')
      "#<#{self.class.name}:0x#{hex_id} name: #{name.inspect}>"
    end
  end
end
