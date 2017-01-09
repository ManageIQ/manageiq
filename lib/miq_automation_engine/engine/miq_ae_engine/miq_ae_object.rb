require 'more_core_extensions/core_ext/array/math'
require_relative 'miq_ae_state_machine'
module MiqAeEngine
  class MiqAeObject
    include MiqAeStateMachine
    PATH_SEPARATOR    = '/'
    MESSAGE_SEPARATOR = ','
    ENUM_SEPARATOR    = ','
    CLASS_SEPARATOR   = '::'
    COLLECT_SEPARATOR = ';'
    METHOD_SEPARATOR  = '.'
    DEFAULT_INSTANCE  = '.default'
    MISSING_INSTANCE  = '.missing'
    OPAQUE_PASSWORD   = '********'
    FIELD_ATTRIBUTES  = %w( collect on_entry on_exit on_error max_retries max_time )
    FIELD_VALUES      = %w( value default_value )
    FIELD_ALLKEYS     = FIELD_VALUES + FIELD_ATTRIBUTES

    BASE_NAMESPACE    = '$'
    BASE_CLASS        = 'object'
    BASE_OBJECT       = [BASE_NAMESPACE, BASE_CLASS].join(PATH_SEPARATOR)
    RE_METHOD_CALL    = /^[\s]*([\.\/\w]+)[\s]*(?:\((.*)\))?[\s]*$/
    RE_URI_ESCAPE     = Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")
    RE_SUBST          = /\$\{([^}]+)\}/
    RE_COLLECT_ARRAY  = /^[\s]*(?:([\.\/\w]+)[\s]*=[\s]*)?\[(.*)\](?:\.([^.]+))?/
    RE_COLLECT_HASH   = /^[\s]*(?:([\.\/\w]+)[\s]*=[\s]*)?\{(.*)\}(?:\.([^.]*))*/
    RE_COLLECT_STRING = /^[\s]*(?:([\.\/\w]+)[\s]*=[\s]*)?([\w]+)(?:\.([^.]*))*/
    # key => value {, key => value }*
    #                     Key    =>   number | "string" | 'string' | variable
    RE_HASH           = /(\w+)\s*=>\s*(\d+|\"[^\"]+\"|\'[^\']+\'|\w+)/
    # Default conversion for Service Models
    SM_LOOKUP         = Hash.new { |_, k| k.classify }.merge(
      'ems'                    => 'ExtManagementSystem',
      'host_provision'         => 'MiqHostProvision',
      'host_provision_request' => 'MiqHostProvisionRequest',
      'policy'                 => 'MiqPolicy',
      'provision'              => 'MiqProvision',
      'provision_request'      => 'MiqProvisionRequest',
      'request'                => 'MiqRequest',
      'server'                 => 'MiqServer'
    )
    NULL_COALESCING_OPERATOR = '||'.freeze
    attr_accessor :attributes, :namespace, :klass, :instance, :object_name, :instance_methods, :workspace, :current_field, :current_message
    attr_accessor :node_parent
    attr_reader :node_children

    def initialize(workspace, ns, klass, instance, object_name = nil)
      Benchmark.current_realtime[:object_count] += 1

      @workspace        = workspace
      @namespace        = ns
      @klass            = klass
      @instance         = instance
      @attributes       = {}
      @fields           = {}
      @fields_ordered   = []
      @rels             = {}
      @instance_methods = {}
      @object_name      = object_name || MiqAeObject.fqname(@namespace, @klass, @instance)
      @class_fqname     = MiqAeClass.fqname(@namespace, @klass)
      @aec              = fetch_class
      @current_field    = nil
      @current_message  = nil
      @node_parent      = nil
      @node_children    = []

      # Collect Class and Instance Methods into Hashes
      unless @aec.nil?
        @aec.instance_methods.each { |m| @instance_methods[m.name.downcase] = m }

        @cm = @workspace.class_methods[@class_fqname.downcase] || {}
        @aec.class_methods.each { |m| @cm[m.name.downcase] = m unless @cm.key?(m.name.downcase) }
        @workspace.class_methods[@class_fqname.downcase] = @cm
      end

      @aei = nil
      if @instance.nil?
        @instance = DEFAULT_INSTANCE
      elsif !@aec.nil?
        Benchmark.realtime_block(:instance_fetch_time) do
          @aei = fetch_instance(@instance)
          if @aei.nil?
            $miq_ae_logger.info("Instance [#{@object_name}] not found in MiqAeDatastore - trying [#{MISSING_INSTANCE}]")
            # Try the .missing instance, if the requested one was not found
            @attributes['_missing_instance'] = @instance
            @instance = MISSING_INSTANCE
            @aei      = fetch_instance(@instance)
          end
        end

        raise MiqAeException::InstanceNotFound, "Instance [#{@object_name}] not found in MiqAeDatastore" if @aei.nil?
      end

      unless @aec.nil?
        Benchmark.realtime_block(:fields_time) do
          fields, = Benchmark.realtime_block(:field_fetch_time) { @aec.ae_fields }
          fields.each do |f|
            Benchmark.current_realtime[:fetch_field_count] += 1
            attrs, = Benchmark.realtime_block(:field_attributes_time) { f.attributes }
            unless @aei.nil?
              attrs['value'] = @aei.get_field_value(f, false)
              FIELD_ATTRIBUTES.each do |key|
                attrib     = @aei.get_field_attribute(f, false, key.to_sym)
                attrs[key] = attrib unless attrib.blank?
              end
            end
            @fields[f.name]  = attrs
            @fields_ordered << f.name
          end
        end
      end

      # Nothing more to do if Base Class
      return if @namespace.downcase == BASE_NAMESPACE && @klass.downcase == BASE_CLASS

      # Make sure we found what we needed before proceeding
      raise MiqAeException::ClassNotFound, "Class [#{@class_fqname}] not found in MiqAeDatastore" if @aec.nil?

      Benchmark.realtime_block(:inherit_time) do
        # Who do we inherit from
        @inherits = BASE_OBJECT

        parts     = @inherits.split(PATH_SEPARATOR)
        klass     = parts.pop
        ns        = parts.empty? ? @namespace : parts.join(PATH_SEPARATOR)
        instance  = @aei.nil? ? nil : @aei.inherits
        inherited = MiqAeObject.new(workspace, ns, klass, instance)
        ordered   = []
        inherited.fields.each do |f|
          k = f['name']
          if @fields.key?(k)
            FIELD_ALLKEYS.each { |hk| @fields[k][hk] ||= f[hk] }
          else
            @fields[k] = f
            ordered << k
          end
        end
        @fields_ordered = ordered + @fields_ordered

        # Set the inherited instance methods
        inherited.instance_methods.each { |k, v| @instance_methods[k.downcase] = v unless @instance_methods.key?(k.downcase) }

        # Set the inherited class methods
        inherited_class_fqname = MiqAeClass.fqname(ns, klass)
        unless @workspace.class_methods[inherited_class_fqname.downcase].nil?
          @workspace.class_methods[inherited_class_fqname.downcase].each { |k, v| @cm[k.downcase] = v unless @cm.key?(k.downcase) }
          @workspace.class_methods[@class_fqname.downcase] = @cm
        end
      end
    end

    def fetch_namespace(ns = @namespace)
      Benchmark.current_realtime[:fetch_namespace_count] += 1
      Benchmark.realtime_block(:fetch_namespace_time) do
        @workspace.datastore(ns.downcase, :namespace) do
          MiqAeNamespace.find_by_fqname(ns)
        end
      end.first
    end

    def fetch_class(fqname = @class_fqname)
      Benchmark.current_realtime[:fetch_class_count] += 1
      Benchmark.realtime_block(:fetch_class_time) do
        @workspace.datastore(fqname.downcase.to_sym, :class) do
          ns, name = MiqAeClass.parse_fqname(fqname)
          ns = fetch_namespace(ns)
          return nil if ns.nil?

          ns.ae_classes.detect { |c| name.casecmp(c.name) == 0 }
        end
      end.first
    end

    def fetch_instance(iname)
      Benchmark.current_realtime[:fetch_instance_count] += 1
      Benchmark.realtime_block(:fetch_instance_time) do
        @workspace.datastore(@class_fqname.downcase.to_sym, iname.downcase) do
          @aec.ae_instances.detect { |i| iname.casecmp(i.name) == 0 }
        end
      end.first
    end

    def fetch_field_value(f)
      Benchmark.current_realtime[:fetch_field_value_count] += 1
      Benchmark.realtime_block(:fetch_field_value_time) do
        @aei.get_field_value(f, false) unless @aei.nil?
      end.first
    end

    def state_machine?
      @aec.state_machine?
    end

    def attribute_value_to_xml(value, xml)
      case value.class.to_s
      when 'MiqAePassword'            then xml.Password OPAQUE_PASSWORD
      when 'String'                   then xml.String   value
      when 'Fixnum'                   then xml.Fixnum   value
      when 'Symbol'                   then xml.Symbol   value.to_s
      when 'TrueClass', 'FalseClass'  then xml.Boolean  value.to_s
      when /MiqAeMethodService::(.*)/ then xml.tag!($1.gsub(/::/, '-'), :object_id => value.object_id, :id => value.id)
      when 'Array'                    then xml.Array  do
        value.each_index do |i|
          xml.Element(:index => i + 1) { attribute_value_to_xml(value[i], xml) }
        end
      end
      when 'Hash'                     then xml.Hash do
        value.each do |k, v|
          xml.Key(:name => k.to_s) { attribute_value_to_xml(v, xml) }
        end
      end
      when 'DRb::DRbUnknown'
        $miq_ae_logger.error "Found DRbUnknown for value: #{value.inspect} in XML: #{xml.inspect}"
        xml.String value
      else
        xml.tag!(value.class.to_s.gsub(/::/, '-')) { xml.cdata! value.inspect }
      end
    end

    def to_xml(options = {})
      require 'builder'
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml_attrs = {:namespace => @namespace, :class => @klass, :instance => @instance}
      xml.MiqAeObject(xml_attrs) do
        @attributes.keys.sort.each do |k|
          xml.MiqAeAttribute(:name => k) { attribute_value_to_xml(@attributes[k], xml) }
        end

        children.each { |c| c.to_xml(:builder => xml) }
      end
    end

    def fields(message = nil)
      @fields_ordered.collect do |fname|
        @fields[fname] if message.nil? || self.class.message_matches?(message_parse(@fields[fname]['message']), message)
      end.compact
    end

    def [](attr)
      attributes[attr.downcase]
    end

    def []=(attr, value)
      attributes[attr.downcase] = value
    end

    def process_assertions(message)
      process_filtered_fields(['assertion'], message)
    end

    def user_info_attributes(user)
      {'user' => user, 'tenant' => user.current_tenant, 'miq_group' => user.current_group}.each do |k, v|
        value = MiqAeObject.convert_value_based_on_datatype(v.id, v.class.name)
        @attributes[k] = value unless value.nil?
      end
    end

    def process_args_as_attributes(args = {})
      args.keys.each { |k| MiqAeEngine.automation_attribute_is_array?(k) ? process_args_array(args, k) : process_args_attribute(args, k) }
      @attributes.merge!(args)
    end

    def process_args_array(args, args_key)
      # process Array::servers => MiqServer::2,MiqServer::3,MiqServer::4
      key = args_key.split(CLASS_SEPARATOR).last
      value = args.delete(args_key)
      args[key] = load_array_objects_from_string(value)
    end

    def process_args_attribute(args, args_key)
      # process MiqServer::svr => 2
      if args_key.include?(CLASS_SEPARATOR)
        key, klass = get_key_name_and_klass_from_key(args_key)
        value = args.delete(args_key)
        args["#{key}_id"] = value unless @attributes.key?(key)
        args[key] = MiqAeObject.convert_value_based_on_datatype(value, klass)
      else
        args[args_key.downcase] = args.delete(args_key) if args_key != args_key.downcase
      end
    end

    def load_array_objects_from_string(objects_str)
      objects_str.split(',').collect do |o|
        klass, str_value = o.split(CLASS_SEPARATOR)
        value = MiqAeObject.convert_value_based_on_datatype(str_value, klass)
        value if value.kind_of?(MiqAeMethodService::MiqAeServiceModelBase)
      end.compact
    end

    def get_key_name_and_klass_from_key(attribute_key)
      # If user passed in a datatype as part of the attribute name (e.g. MiqServer::svr => 2), process it
      sp    = attribute_key.split(CLASS_SEPARATOR)
      klass = sp[0..-2].join(CLASS_SEPARATOR)
      key   = sp.last.downcase
      return key, klass
    end

    def process_attributes(message, args = {})
      process_filtered_fields(['attribute'], message, args)
    end

    def process_fields(message, args = {})
      process_filtered_fields(['attribute', 'method', 'relationship', 'state'], message, args)
    end

    def process_filtered_fields(aetypes, message, args = {})
      fields(message).each do |f|
        next unless aetypes.include?(f['aetype'])
        begin
          @current_field   = f
          @current_message = message
          send("process_#{f['aetype']}", f, message, args)
        ensure
          @current_message = nil
          @current_field   = nil
        end
      end
    end

    def current_field_name
      current_field_element('name')
    end

    def current_field_type
      current_field_element('aetype')
    end

    def current_field_element(elem)
      @current_field ? @current_field[elem.to_s] : nil
    end

    def self.message_matches?(possible, message)
      possible.any? { |p| p == message || p == '*' }
    end

    def message_parse(message)
      return ['create'] if message.blank?
      message.split(MESSAGE_SEPARATOR).collect { |m| m.strip.downcase }
    end

    def children(name = nil)
      return node_children if name.nil?
      @rels[name]
    end

    def self.fqname(ns, klass, instance)
      MiqAePath.new(:ae_namespace => ns, :ae_class => klass, :ae_instance => instance).to_s
    end

    def process_relationship(f, message, args)
      process_relationship_raw(get_value(f, :aetype_relationship), message, args, f['name'], f['collect'])
    end

    def process_method_raw(method, collect = nil)
      return if method.blank? || method.lstrip[0, 1] == '#'

      Benchmark.current_realtime[:method_count] += 1
      Benchmark.realtime_block(:method_time) do
        result = RE_METHOD_CALL.match(method)
        raise MiqAeException::InvalidMethod, "invalid method calling syntax: [#{method}]" if result.nil?

        ns, klass, method_name = fqmethod2components(result[1])
        hashed_args            = method_parms_to_hash(result[2])

        method_result = invoke_method(ns, klass, method_name, hashed_args)
        self[collect] = method_result unless collect.blank?
      end
    end

    def process_method(f, _message, _args)
      process_method_raw(get_value(f), f['collect'])
    end

    def process_method_via_uri(uri)
      scheme, userinfo, host, port, registry, path, opaque, query, fragment = MiqAeUri.split(uri)
      parts = path.split(PATH_SEPARATOR)
      parts.shift # Remove the leading blank piece
      method_name = parts.pop
      klass       = parts.pop
      ns          = parts.join(PATH_SEPARATOR)
      [ns, klass, method_name].each { |k| k.downcase! unless k.nil? }

      invoke_method(ns, klass, method_name, MiqAeUri.query2hash(query))
    end

    def uri2value(uri, required = false)
      scheme, userinfo, host, port, registry, path, opaque, query, fragment = MiqAeUri.split(uri)

      if scheme == 'miqaedb'
        ns, klass, instance, attribute_name = MiqAePath.split(path, :has_attribute_name => true)
        ns = @workspace.overlay_namespace(scheme, uri, ns, klass, instance)
        o = MiqAeObject.new(@workspace, ns, klass, instance)
        message = fragment.nil? ? 'create' : fragment.downcase
        o.process_attributes(message)
        return o.attributes[attribute_name.downcase]
      end

      if scheme == 'miqaews'
        if path.starts_with?('!')
          return @workspace.current_message if path.downcase == '!current_message'
          raise MiqAeException::MethodNotFound, "Method [#{path}] Not Found for Current Object"
        end
        o = @workspace.get_obj_from_path(path)
        raise MiqAeException::ObjectNotFound, "Object Not Found for path=[#{path}]"  if o.nil?

        frags          = fragment.split('.')
        attribute_name = frags.shift
        methods        = frags

        if required && !o.attributes.key?(attribute_name.downcase)
          raise MiqAeException::AttributeNotFound, "Attribute #{attribute_name} not found for object [#{path}]"
        end

        value          = o.attributes[attribute_name.downcase]
        begin
          methods.each { |meth| value = call_method(value, meth) }
        rescue => err
          $miq_ae_logger.warn "Error during substitution: #{err.message}"
          return nil
        end
        return value
      end

      uri  # if it was not processed, return the original uri
    end

    private

    def call_method(obj, method)
      result = RE_METHOD_CALL.match(method)
      raise MiqAeException::InvalidMethod, "invalid method calling syntax: [#{method}]" if result.nil?
      if result[2]
        args = result[2]
        args = result[2][1..-1].to_sym if result[2][0] == ':'
        obj.send(result[1], args)
      else
        obj.send(result[1])
      end
    end

    def invoke_method(namespace, klass, method_name, args)
      aem = nil

      # No class means an instance method
      aem = @instance_methods[method_name.downcase] if klass.nil?
      # If not found in instance methods, look in class methods

      namespace_provided = namespace
      namespace ||= @namespace
      klass ||= @klass
      fq = MiqAeClass.fqname(namespace, klass)
      if aem.nil?
        cm  = @workspace.class_methods[fq.downcase]
        aem = cm[method_name] unless cm.nil?
      end

      aem = method_override(namespace, klass, method_name, aem)
      if aem.nil?
        method_aec = fetch_class(fq)
        aem = method_aec.ae_methods.detect { |c| c[:name] == method_name } unless method_aec.nil?
      end

      raise MiqAeException::MethodNotFound, "Method [#{method_name}] not found in class [#{fq}]" if aem.nil?
      begin
        @workspace.push_method(method_name)
        return MiqAeEngine::MiqAeMethod.invoke(self, aem, args)
      ensure
        @workspace.pop_method
      end
    end

    def method_override(namespace, klass, method_name, aem)
      ns = namespace.split('/')
      ns.shift
      updated_ns = @workspace.overlay_method(ns.join('/'), klass, method_name)
      if updated_ns != namespace
        cls = ::MiqAeClass.find_by_fqname("#{updated_ns}/#{klass}")
        aem = ::MiqAeMethod.find_by_class_id_and_name(cls.id, method_name) if cls
      end
      aem
    end

    def get_value(f, type = nil, required = false)
      value = f['value']
      value = f['default_value'] if value.blank?
      value = substitute_value(value, type, required) if f['substitute'] == true
      value
    end

    def get_null_coalesced_value(f, type = nil)
      initial_value = f['value'] || f['default_value']
      return nil unless initial_value

      result = nil
      initial_value.split(NULL_COALESCING_OPERATOR).each do |value|
        result = resolve_value(value, type)
        break unless result.blank?
      end
      result
    end

    def resolve_value(value, type)
      current_value = value.strip
      substitute_value(current_value, type)
    rescue => err
      $miq_ae_logger.warn("#{err.message}, while evaluating :#{current_value} null coalecing attribute")
      nil
    end

    def self.convert_boolean_value(value)
      return true   if value.to_s.downcase == 'true' || value == '1'
      return false  if value.to_s.downcase == 'false' || value == '0'
      value
    end

    def self.convert_value_based_on_datatype(value, datatype)
      return value if value.blank?

      # Basic Types
      return convert_boolean_value(value)                    if datatype == 'boolean'
      return true                                            if datatype == 'TrueClass'
      return false                                           if datatype == 'FalseClass'
      return Time.parse(value)                               if datatype == 'time' || datatype == 'Time'
      return value.to_sym                                    if datatype == 'symbol' || datatype == 'Symbol'
      return value.to_i                                      if datatype == 'integer' || datatype == 'Fixnum'
      return value.to_f                                      if datatype == 'float' || datatype == 'Float'
      return value.gsub(/[\[\]]/, '').strip.split(/\s*,\s*/)  if datatype == 'array' && value.class == String
      return MiqAePassword.new(MiqAePassword.decrypt(value)) if datatype == 'password'

      if datatype &&
         (service_model = "MiqAeMethodService::MiqAeService#{SM_LOOKUP[datatype]}".safe_constantize)
        return service_model.find(value)
      end

      # default datatype => 'string'
      value
    end

    def substitute_value(value, _type = nil, required = false)
      Benchmark.current_realtime[:substitution_count] += 1
      Benchmark.realtime_block(:substitution_time) do
        value = value.gsub(RE_SUBST) do |_s|
          subst   = uri2value($1, required)
          subst &&= subst.to_s
          # This encoding of relationship is not needed, until we can get a valid use case
          # Based on RFC 3986 Section 2.4 "When to Encode or Decode"
          # We are properly encoding when we send URL requests to external systems
          # or building an automate request
          # subst &&= URI.escape(subst, RE_URI_ESCAPE)  if type == :aetype_relationship
          subst
        end unless value.nil?
        return value
      end
    end

    def process_assertion(f, message, args)
      Benchmark.current_realtime[:assertion_count] += 1
      Benchmark.realtime_block(:assertion_time) do
        assertion = get_value(f, :aetype_assertion, true)
        return if assertion.blank?

        $miq_ae_logger.info("Evaluating substituted assertion [#{assertion}]")

        begin
          _, _ = message, args # used by eval (?)
          assertion_result = eval(assertion)
        rescue SyntaxError => err
          $miq_ae_logger.error("Assertion had the following Syntax Error: '#{err.message}'")
          raise MiqAeException::AssertionFailure, "Syntax Error in Assertion: <#{assertion}>"
        rescue Exception => err
          $miq_ae_logger.error("'#{err.message}', evaluating assertion")
          raise MiqAeException::AssertionFailure, "Assertion Evaluation Failed: <#{assertion}>"
        end

        raise MiqAeException::AssertionFailure, "Assertion Failed: <#{assertion}>" unless assertion_result
      end
    end

    def process_attribute(f, _message, _args, value = nil)
      Benchmark.current_realtime[:attribute_count] += 1
      Benchmark.realtime_block(:attribute_time) do
        if value.nil?
          value = if f['datatype'] == MiqAeField::NULL_COALESCING_DATATYPE
                    get_null_coalesced_value(f)
                  else
                    get_value(f)
                  end
        end
        value = MiqAeObject.convert_value_based_on_datatype(value, f['datatype'])
        @attributes[f['name'].downcase] = value unless value.nil?
        process_collect(f['collect'], nil) unless f['collect'].blank?
      end
    end

    def process_relationship_raw(relationship, message, args, name, collect)
      return if relationship.blank? || relationship.lstrip[0, 1] == '#'

      Benchmark.current_realtime[:relationship_count] += 1

      scheme, userinfo, host, port, registry, path, opaque, query, fragment = MiqAeUri.split(relationship, 'miqaedb')
      fragment = message                   if fragment.nil?
      query    = MiqAeUri.hash2query(args) if query.nil?
      relationship = MiqAeUri.join(scheme, userinfo, host, port, registry, path, opaque, query, fragment)

      $miq_ae_logger.info("Following Relationship [#{relationship}]")
      if relationship.include?('*')
        rels = []
        wildcard_expand(relationship).each do|r|
          Benchmark.current_realtime[:relationship_followed_count] += 1
          rels << @workspace.instantiate(r, @workspace.ae_user, self)
        end
        process_collects(collect, rels)
      else
        Benchmark.current_realtime[:relationship_followed_count] += 1
        rels = @workspace.instantiate(relationship, @workspace.ae_user, self)
        process_collects(collect, rels)
      end
      @rels[name] = rels
      $miq_ae_logger.info("Followed  Relationship [#{relationship}]")
    end

    def process_collects(what, rels)
      return if rels.nil? || what.nil?
      what.to_s.split(COLLECT_SEPARATOR).each { |expr| process_collect(expr, rels) }
    end

    def process_collect(expr, rels)
      Benchmark.current_realtime[:collect_count] += 1
      Benchmark.realtime_block(:collect_time) do
        if    result = RE_COLLECT_ARRAY.match(expr)
          process_collect_array(expr, rels, result)
        elsif result = RE_COLLECT_HASH.match(expr)
          process_collect_hash(expr, rels, result)
        elsif result = RE_COLLECT_STRING.match(expr)
          process_collect_string(expr, rels, result)
        else
          raise MiqAeException::InvalidCollection, "invalid collect item: <#{expr}>"
        end
      end.first
    end

    def process_collect_set_attribute(k, v)
      k = @current_field['name'] if k.nil? && @current_field.kind_of?(Hash)
      return v if k.nil?

      parts = k.split(PATH_SEPARATOR)
      left = parts.pop
      unless parts.empty?
        path = parts.first.blank? ? PATH_SEPARATOR : parts.join(PATH_SEPARATOR)
        obj = @workspace.get_obj_from_path(path)
      else
        obj = self
      end
      obj.attributes[left.downcase] = v unless obj.nil?
    end

    def process_collect_array(_expr, rels, result)
      lh       = result[1].strip          unless result[1].nil?
      contents = result[2].strip
      method   = result[3].strip.downcase unless result[3].nil?

      elems = []
      contents.split(ENUM_SEPARATOR).each do |e|
        elem = e.strip
        elems << elem unless elem.empty?
      end

      array = []
      if rels.kind_of?(Array)
        rels.collect { |r| elems.each { |e| array << r[e] } }
      elsif rels.nil?
        elems.each { |e| array << classify_value(e) }
      else
        elems.each { |e| array << rels[e] }
      end

      return if array.length == 0

      process_collect_set_attribute(lh, array_value(array, method))
    end

    def array_value(array, method)
      return array if array.nil? || array.compact.empty?
      case method
      when 'rsort'                  then array.sort { |x, y| y <=> x }
      when 'sort'                   then array.sort
      when 'reverse'                then array.reverse
      when 'count'                  then array.length
      when 'min', 'minimum'         then array.min
      when 'max', 'maximum'         then array.max
      when 'sum'                    then array.sum
      when 'mean', 'average', 'avg' then array.mean
      when 'variance'               then array.variance
      when 'stddev', 'stdev'        then array.stddev
      else array
      end
    end

    def process_collect_hash(expr, rels, result)
      lh       = result[1].strip          unless result[1].nil?
      contents = result[2].strip
      method   = result[3].strip.downcase unless result[3].nil?

      hash  = {}
      hashes = contents.split(ENUM_SEPARATOR)
      hashes.each do |hashContents|
        hashDetails = hashContents.split('=>')
        raise MiqAeException::InvalidCollection, "invalid hash in collect item <#{expr}>" if hashDetails.length != 2
        left  = hashDetails[0].strip

        if left[0, 1] == ':'
          ltype = :symbol
          left  = left[1..-1].to_sym
        elsif ["\"", "\'"].include?(left[0, 1])
          ltype = :string
          left  = left[1..-2]
        else
          ltype = :value
        end

        right = hashDetails[1].strip

        if rels.kind_of?(Array)
          if ltype == :value
            rels.collect { |r| hash[r[left]] = r[right] }
          else
            rels.collect { |r| hash[left]    = r[right] }
          end
        elsif rels.nil?
          if ltype == :value
            hash[self[left]] = self[right]
          else
            hash[left]       = self[right]
          end
        else
          if ltype == :value
            hash[rels[left]] = rels[right]
          else
            hash[left]       = rels[right]
          end
        end
      end
      process_collect_set_attribute(lh, hash) unless hash.length == 0
    end

    def process_collect_string(_expr, rels, result)
      cattr   = result[1].strip          unless result[1].nil?
      name    = result[2].strip
      method  = result[3].strip.downcase unless result[3].nil?
      cattr ||= name                     unless rels.nil?  # Set cattr to name ONLY if coming from relationship

      if rels.kind_of?(Array)
        value = rels.collect { |r| r[name] }
      elsif rels.nil?
        value = self[name]
      else
        value = rels[name]
      end
      process_collect_set_attribute(cattr, value)
    end

    def wildcard_expand(rel)
      return [] if rel.blank?

      scheme, userinfo, host, port, registry, path, opaque, query, fragment = MiqAeUri.split(rel)
      return [rel] unless MiqAePath.has_wildcard?(path)

      ns, klass, instance = MiqAePath.split(path)

      ns = @workspace.overlay_namespace(scheme, rel, ns, klass, instance)

      aec = fetch_class(MiqAeClass.fqname(ns, klass))
      return [] unless aec
      aec.ae_instances.search(instance).collect do|i|
        path = MiqAePath.new(:ae_namespace => ns, :ae_class => klass, :ae_instance => i).to_s
        MiqAeUri.join(scheme, userinfo, host, port, registry, path, opaque, query, fragment)
      end.sort
    end

    def fqmethod2components(str)
      parts = str.split(METHOD_SEPARATOR)
      raise MiqAeException::InvalidMethod, "invalid method name: [#{str}]" if parts.length > 2

      method_name = parts.pop
      klass       = nil
      ns          = nil

      unless parts.length == 0
        parts = parts.pop.split(PATH_SEPARATOR)
        klass = parts.pop
        ns    = parts.join(PATH_SEPARATOR) unless parts.length == 0
      end

      [ns, klass, method_name].each { |k| k.downcase! unless k.nil? }

      return ns, klass, method_name
    end

    def method_parms_to_hash(str)
      h = {}

      while result = RE_HASH.match(str)
        key    = result[1]
        value  = result[2]
        h[key] = classify_value(value)
        str    = result.post_match
      end

      h
    end

    def classify_value(value)
      if value.starts_with?("'")
        raise "Unmatched Single Quoted String <#{e}> in Collect" unless value.ends_with?("'")
        return value[1..-2]
      elsif value.starts_with?("\"")
        raise "Unmatched Double Quoted String <#{e}> in Collect" unless value.ends_with?("\"")
        return value[1..-2]
      elsif /^[+-]?[0-9]+\s*$/.match(value)
        return value.to_i
      elsif /^[-+]?[0-9]+\.[0-9]+\s*$/.match(value)
        return value.to_f
      else
        return self[value]
      end
    end
  end
end
