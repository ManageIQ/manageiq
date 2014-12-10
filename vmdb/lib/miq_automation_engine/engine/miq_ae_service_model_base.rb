module MiqAeMethodService
  class MiqAeServiceConverter
    def self.svc2obj(svc)
      svc.instance_variable_get("@object")
    end
  end

  class MiqAeServiceModelBase
    EXPOSED_ATTR_BLACK_LIST = [/password/, /^auth_key$/]
    class << self
      include DRbUndumped  # Ensure that Automate Method can get at the class itself over DRb
    end

    include DRbUndumped    # Ensure that Automate Method can get at instances over DRb
    include MiqAeServiceObjectCommon

    def self.method_missing(m, *args)
      return wrap_results(model.send(m, *args)) if class_method_exposed?(m)
      super
    rescue ActiveRecord::RecordNotFound
      raise MiqAeException::ServiceNotFound, "Service Model not found"
    end

    def self.respond_to?(m, *args)
      return true if class_method_exposed?(m.to_sym)
      super
    end

    # Expose the ActiveRecord find, all, count, and first
    def self.class_method_exposed?(m)
      m.to_s.starts_with?('find_') || [:find, :all, :count, :first].include?(m)
    end
    private_class_method :class_method_exposed?

    def self.inherited(subclass)
      subclass.class_eval do
        model.column_names_with_virtual.each do |attr|
          next if EXPOSED_ATTR_BLACK_LIST.any? { |rexp| attr =~ rexp }
          next if subclass.base_class != self && method_defined?(attr)
          expose attr
        end
      end
    end

    def self.associations
      @associations ||= []
      super_assoc = superclass.respond_to?(:associations) ? superclass.associations : []
      (super_assoc + @associations).sort
    end

    def associations
      self.class.associations
    end

    def self.association(*args)
      args.each { |method_name| self.association = method_name }
    end

    def self.association=(meth)
      @associations ||= []
      @associations << meth.to_s unless @associations.include?(meth.to_s)
    end

    def self.base_class
      @base_class ||= begin
        MiqAeMethodService.const_get("MiqAeService#{model.base_class.name}")
      end
    end

    def self.base_model
      @base_model ||= begin
        MiqAeMethodService.const_get("MiqAeService#{model.base_model.name}")
      end
    end

    def self.model
      # Set a class-instance variable to get the appropriate model
      @model ||= Object.const_get(/MiqAeService(.+)$/.match(self.name)[1])
    end
    private_class_method :model

    def self.expose(*args)
      raise ArgumentError, "must pass at least one method name" if args.empty? || args.first.is_a?(Hash)
      options = args.last.kind_of?(Hash) ? args.pop : {}
      raise ArgumentError, "cannot have :method option if there is more than one method name specified" if options.has_key?(:method) && args.length != 1

      args.each do |method_name|
        next if method_name.to_sym == :id
        self.association = method_name if options[:association]
        define_method(method_name) do |*params|
          ret = object_send(options[:method] || method_name, *params)
          return options[:override_return] if options.has_key?(:override_return)
          return wrap_results(ret)
        end
      end
    end
    private_class_method :expose

    def self.wrap_results(results)
      ret = nil
      ar_method do
        if results.nil?
          ret = nil
        elsif results.kind_of?(Array)
          ret = results.collect { |r| self.wrap_results(r) }
        elsif results.kind_of?(ActiveRecord::Base)
          klass = MiqAeMethodService.const_get("MiqAeService#{results.class.name}")
          ret = self.drb_return(klass.new(results))
        else
          ret = results
        end
      end
      ret
    end

    def wrap_results(results)
      self.class.wrap_results(results)
    end

    def self.drb_return(obj)
      MiqAeService.current ? MiqAeService.current.drb_return(obj) : obj
    end

    def drb_return(obj)
      self.class.drb_return(obj)
    end

    #
    # Convert URI Excluded US-ASCII Characters to underscores
    #
    # The following is a synopsis of section 2.4.3 from http://www.ietf.org/rfc/rfc2396.txt
    #   control     = <US-ASCII coded characters 00-1F and 7F hexadecimal>
    #   space       = <US-ASCII coded character 20 hexadecimal>
    #   delims      = "<" | ">" | "#" | "%" | <">
    #   unwise      = "{" | "}" | "|" | "\" | "^" | "[" | "]" | "`"
    #
    DELIMS = [ '<', '>', '#', '%', "\"" ]
    UNWISE = [ '{', '}', '|', "\\", '^', '[', ']', "\`"]
    def self.normalize(str)
      return str unless str.kind_of?(String)

      arr = str.each_char.collect do |c|
        if DELIMS.include?(c) || UNWISE.include?(c) || c == ' '
          '_'
        else
          ordinal = c.ord
          if (ordinal >= 0x00 && ordinal <= 0x1F) || ordinal == 0x7F
            '_'
          else
            c
          end
        end
      end

      arr.join
    end

    def method_missing(m, *args)
      #
      # Normalize result of any method call
      #  e.g. normalized_ldap_group, will call ldap_group method and normalize the result
      #
      prefix = 'normalized_'
      if m.to_s.starts_with?(prefix)
        method = m.to_s[prefix.length..-1]
        result = MiqAeServiceModelBase.wrap_results(object_send(method, *args))
        return MiqAeServiceModelBase.normalize(result)
      end

      super
    end

    # @param obj [Integer,ActiveRecord::Base] The object id or ActiveRecord instance to wrap
    #   in a service model
    def initialize(obj)
      ar_klass = self.class.send(:model)
      raise ArgumentError.new("#{ar_klass.name} Nil Object specified") if obj.nil?
      if obj.kind_of?(ActiveRecord::Base) && !obj.kind_of?(ar_klass)
        raise ArgumentError.new("#{ar_klass.name} Object expected, but received #{obj.class.name}")
      end
      @object = obj.kind_of?(ar_klass) ? obj : ar_method { ar_klass.find_by_id(obj.to_i) }
      raise MiqAeException::ServiceNotFound, "#{ar_klass.name} Object [#{obj}] not found" if @object.nil?
    end

    def virtual_columns_inspect
      arr = @object.class.virtual_column_names.sort.collect { |vc| "#{vc}: #{@object.send(vc).inspect}" }
      "<#{arr.join(', ')}>"
    end

    def virtual_column_names
      @object.class.virtual_column_names.sort
    end

    def inspect
      ar_method { "\#<#{self.class.name.demodulize}:0x#{self.object_id.to_s(16)} @object=#{@object.inspect}, @virtual_columns=#{virtual_column_names.inspect}, @associations=#{associations.inspect}>" }
    end

    def inspect_all
      ar_method { "\#<#{self.class.name.demodulize}:0x#{self.object_id.to_s(16)} @object=#{@object.inspect}, @virtual_columns=#{virtual_columns_inspect}, @associations=#{associations.inspect}>" }
    end

    def tagged_with?(category, name)
      object_send(:is_tagged_with?, name.to_s, :ns=>"/managed/#{category}")
    end

    def tags(category = nil)
      ns = category.nil? ? "/managed" : "/managed/#{category}"
      object_send(:tag_list, :ns=>ns).split
    end

    def tag_assign(tag)
      ar_method do
        Classification.classify_by_tag(@object, "/managed/#{tag}")
        true
      end
    end

    def tag_unassign(tag)
      ar_method do
        Classification.unclassify_by_tag(@object, "/managed/#{tag}")
        true
      end
    end

    def reload
      object_send(:reload)
      self # Return self to prevent the internal object from being returned
    end

    def object_send(name, *params)
      ar_method do
        begin
          @object.send(name, *params)
        rescue Exception => err
          $miq_ae_logger.error("The following error occurred during instance method <#{name}> for AR object <#{@object.inspect}>")
          raise
        end
      end
    end

    def object_class
      object_send(:class)
    end

    def model_suffix
      @object.class.model_suffix
    end

    def self.ar_method
      begin
        # In UI Worker, query caching is enabled.  This causes problems in Automate DRb Server (e.g. reload does not refetch from SQL)
        ActiveRecord::Base.connection.clear_query_cache if ActiveRecord::Base.connection.query_cache_enabled
        yield
      rescue Exception => err
        $miq_ae_logger.error("MiqAeServiceModelBase.ar_method raised: <#{err.class}>: <#{err.message}>")
        $miq_ae_logger.error(err.backtrace.join("\n"))
        raise
      ensure
        ActiveRecord::Base.connection_pool.release_connection rescue nil
      end
    end

    def ar_method(&block)
      self.class.ar_method(&block)
    end

  end
end

# Register all of the service models for autoload on first use
Dir.glob("#{File.dirname(__FILE__)}/../service_models/miq_ae_service_*.rb").each do |f|
  f = File.basename(f, '.*')
  MiqAeMethodService.autoload(f.camelize.to_sym, "service_models/#{f}")
end
Dir.glob("#{File.dirname(__FILE__)}/../service_models/miq_ae_service_*/*.rb").each do |f|
  p = File.basename(File.dirname(f))
  f = File.basename(f, '.*')
  MiqAeMethodService.const_get(p.camelize.to_sym).autoload(f.camelize.to_sym, "service_models/#{p}/#{f}")
end
