module MiqAeEngine
  class MiqAePath
    attr_reader :ae_namespace, :ae_class, :ae_instance, :ae_attribute

    def initialize(*args)
      options = args.extract_options!
      args = options.values_at(:ae_namespace, :ae_class, :ae_instance, :ae_attribute) unless options.empty?
      @ae_namespace, @ae_class, @ae_instance, @ae_attribute = *args
    end

    def to_s
      return "" if parts.all?(&:blank?)
      parts.join("/")
    end

    def parts
      parts_array = [nil]
      parts_array << @ae_namespace
      parts_array << @ae_class
      parts_array << @ae_instance
      parts_array << @ae_attribute    unless @ae_attribute.blank?
      parts_array
    end

    def self.build(parts)
      self.new(parts)
    end

    def self.parse(path, options = {})
      self.new(*self.split(path, options))
    end

    def self.join(ns, klass, instance, attribute_name = nil)
      return [nil, ns, klass, instance].join("/") if attribute_name.nil?
      return [nil, ns, klass, instance, attribute_name].join("/")
    end

    def self.split(path, options = {})
      options[:has_instance_name] = true unless options.has_key?(:has_instance_name)
      parts = path.split('/')
      parts << nil if path[-1,1] == '/' && options[:has_instance_name]  # Nil instance if trailing /
      parts.shift  if path[0,1]  == '/'                                 # Remove the leading blank piece
      attribute_name = options[:has_attribute_name] ? parts.pop : nil
      instance       = options[:has_instance_name]  ? parts.pop : nil
      klass          = parts.pop
      ns             = parts.join('/')
      [ns, klass, instance, attribute_name].each { |k| k.downcase! unless k.nil? } if options[:downcase]
      return ns, klass, instance, attribute_name
    end

    def self.has_wildcard?(path)
      return false if path.nil?
      return path.last == "*"
    end

    def self.get_domain_ns_klass_inst(fqname, options = {})
      path = MiqAeUri.path(fqname, "miqaedb")
      ns, klass, inst = split(path, options)
      ns_parts = ns.split('/')
      domain   = ns_parts.shift
      ns_sans_domain = ns_parts.join('/')
      return domain, ns_sans_domain, klass, inst
    end
  end
end
