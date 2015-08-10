module MiqAeEngine
  class MiqAeDomainSearch
    def initialize
      @sorted_domains      = MiqAeDomain.enabled.reverse.collect(&:name)
      @fqns_id_cache       = {}
      @fqns_id_class_cache = {}
      @partial_ns          = []
    end

    def get_alternate_domain(scheme, uri, ns, klass, instance)
      return ns if ns.nil? || klass.nil?
      return ns if scheme != "miqaedb"
      return ns if @fqns_id_cache.key?(ns)
      search(uri, ns, klass, instance, nil)
    end

    def get_alternate_domain_method(scheme, uri, ns, klass, method)
      return ns if ns.nil? || klass.nil?
      return ns if scheme != "miqaedb"
      return ns if @fqns_id_cache.key?(ns)
      search(uri, ns, klass, nil, method)
    end

    private

    def search(uri, ns, klass, instance, method)
      unless @partial_ns.include?(ns)
        fqns = MiqAeNamespace.find_by_fqname(ns, false)
        @fqns_id_cache[ns] = fqns.id if fqns
        return ns if fqns
      end
      @partial_ns << ns unless @partial_ns.include?(ns)
      find_first_fq_domain(uri, ns, klass, instance, method)
    end

    def find_first_fq_domain(uri, ns, klass, instance, method)
      # Check if the namespace, klass and instance exist if it does
      # swap out the namespace
      parts = ns.split('/')
      parts.unshift("")
      matching_domain = get_matching_domain(parts, klass, instance, method)
      matching_domain ||= get_matching_domain(parts, klass, MiqAeObject::MISSING_INSTANCE, method)
      if matching_domain
        parts[0]     = matching_domain
        ns = parts.join('/')
        $miq_ae_logger.info("Updated namespace [#{uri}  #{ns}]")
      end
      ns
    end

    def get_matching_domain(ns_parts, klass, instance, method)
      @sorted_domains.detect do |domain|
        ns_parts[0] = domain
        ns_id       = find_fqns_id(ns_parts)
        cls_id      = find_class_id(klass, ns_id) if ns_id
        get_matching(cls_id, instance, method) if cls_id
      end
    end

    def get_matching(cls_id, instance, method)
      instance ? find_instance_id(instance, cls_id) : find_method_id(method, cls_id)
    end

    def find_fqns_id(fqns_parts)
      fqname = fqns_parts.join('/')
      return @fqns_id_cache[fqname] if @fqns_id_cache.key?(fqname)

      ns = MiqAeNamespace.find_by_fqname(fqname, false)
      @fqns_id_cache[fqname] = ns.id if ns
    end

    def find_class_id(class_name, ns_id)
      return nil if class_name.nil? || ns_id.nil?
      key_name = "#{class_name}#{ns_id}"
      return @fqns_id_class_cache[key_name] if @fqns_id_class_cache.key?(key_name)
      ae_class  = MiqAeClass.find_by_namespace_id_and_name(ns_id, class_name)
      @fqns_id_class_cache[key_name] = ae_class.id if ae_class
    end

    def find_instance_id(instance_name, class_id)
      return nil if instance_name.nil? || class_id.nil?
      cls = MiqAeClass.find(class_id)
      ae_instances = cls.load_class_children(MiqAeInstance, nil, instance_name)
      ae_instances.first.try(:id)
    end

    def find_method_id(method_name, class_id)
      return nil if method_name.nil? || class_id.nil?
      ::MiqAeMethod.find_by_name_and_class_id(method_name, class_id).try(:id)
    end
  end
end
