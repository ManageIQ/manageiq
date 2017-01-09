module MiqAeEngine
  class MiqAeDomainSearch
    def initialize
      @fqns_id_cache       = {}
      @fqns_id_class_cache = {}
      @partial_ns          = []
      @prepend_namespace   = nil
    end

    def prepend_namespace=(ns)
      @prepend_namespace = ns.chomp('/').sub(%r{^/}, '')
      $miq_ae_logger.info("Prepend namespace [#{@prepend_namespace}] during domain search")
    end

    def ae_user=(obj)
      @sorted_domains ||= obj.current_tenant.enabled_domains.collect(&:name)
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
        if fqns && !fqns.domain?
          @fqns_id_cache[ns] = fqns.id
          return ns
        end
      end
      @partial_ns << ns unless @partial_ns.include?(ns)
      updated_ns = find_first_fq_domain(uri, "#{@prepend_namespace}/#{ns}", klass, instance, method) if @prepend_namespace
      updated_ns ||= find_first_fq_domain(uri, ns, klass, instance, method)
      updated_ns || ns
    end

    def find_first_fq_domain(uri, ns, klass, instance, method)
      # Check if the namespace, klass and instance exist if it does
      # swap out the namespace
      parts = ns.split('/')
      parts.unshift("")
      matching_domain = get_matching_domain(parts, klass, instance, method)
      matching_domain ||= get_matching_domain(parts, klass, MiqAeObject::MISSING_INSTANCE, method)
      updated_ns = nil
      if matching_domain
        parts[0]   = matching_domain
        updated_ns = parts.join('/')
        $miq_ae_logger.info("Updated namespace [#{uri}  #{updated_ns}]")
      end
      updated_ns
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

      class_filter = MiqAeClass.arel_table[:name].lower.matches(class_name.downcase)
      ae_class  = MiqAeClass.where(class_filter).where(:namespace_id => ns_id)
      @fqns_id_class_cache[key_name] = ae_class.first.id if ae_class.any?
    end

    def find_instance_id(instance_name, class_id)
      return nil if instance_name.nil? || class_id.nil?
      instance_name = ::ActiveRecordQueryParts.glob_to_sql_like(instance_name).downcase
      ae_instance_filter = MiqAeInstance.arel_table[:name].lower.matches(instance_name)
      ae_instances = MiqAeInstance.where(ae_instance_filter).where(:class_id => class_id)
      ae_instances.first.try(:id)
    end

    def find_method_id(method_name, class_id)
      return nil if method_name.nil? || class_id.nil?
      ae_method_filter = ::MiqAeMethod.arel_table[:name].lower.matches(method_name)
      ae_methods = ::MiqAeMethod.where(ae_method_filter).where(:class_id => class_id)
      ae_methods.first.try(:id)
    end
  end
end
