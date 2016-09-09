class MiqAeBrowser
  attr_accessor :user

  # Automate Datastore Browser starting at MiqAeDomain
  #   - Starting point of searches using fqname
  #   - Searches down to the MiqAeInstances and MiqAeMethods
  #   - Returns array of objects
  #
  # Supporting options:
  #   :depth
  #          0 - starting object only
  #          1 - object + first level children
  #          2 - object + first and second level children
  #          ...
  #        nil - object + whole subtree
  #   :serialize
  #       when true, return the Hash serialized objects including fqname, domain_fqname and klass
  #       i.e.
  #         {
  #           "fqname": "/ManageIQ/System/Request",
  #           "domain_fqname": "/System/Request",       # fqname relative to /domain
  #           "klass": "MiqAeClass",
  #           "id": 75,
  #           "description": "Automation Requests",
  #           "name": "Request",
  #           "created_on": "2015-12-09T20:56:44Z",
  #           "updated_on": "2015-12-09T20:56:44Z",
  #           "namespace_id": 41,
  #           "updated_by": "system"
  #         }
  #   :state_machines
  #       when true, only objects belonging to a sub-tree that includes
  #       state machine entrypoints are returned.
  #

  def initialize(user = User.current_user)
    raise "Must be authenticated before using #{self.class.name}" unless user
    @user = user
    @waypoint_ids = MiqAeClass.waypoint_ids_for_state_machines
  end

  def search(object_ref = nil, options = {})
    object = object_ref
    if object_ref.kind_of?(String)
      if object_ref.blank? || object_ref == "/"
        object = nil
      else
        object = find_base_object(object_ref, options)
        raise "Invalid Automate object path #{object_ref} specified to search" if object.blank?
      end
    end
    start_search(object, options[:depth], options)
  end

  private

  def start_search(object, depth, options = {})
    if options[:serialize]
      search_model(object, depth, options).collect { |obj| serialize(obj) }
    else
      search_model(object, depth, options).collect(&:ae_object)
    end
  end

  def search_model(object, depth, options)
    if object
      search_object(object, depth, options)
    else
      search_domains(depth, options)
    end.flatten
  end

  def search_object(object, depth, options)
    case depth
    when -1 then []
    when 0 then Array(object)
    else
      Array(object) + children(object, options).collect do |child|
                        search_model(child, depth.nil? ? nil : depth - 1, options)
                      end
    end
  end

  def search_domains(depth, options)
    case depth
    when -1 then []
    when 0 then []
    else domains(options).collect do |domain|
           search_model(domain, depth.nil? ? nil : depth - 1, options)
         end
    end
  end

  def serialize(object)
    object.ae_object.attributes.reverse_merge(
      "fqname"        => object.fqname,
      "domain_fqname" => object.domain_fqname,
      "klass"         => object.ae_object.class.name
    )
  end

  def domains(options = {})
    filter_ae_objects(@user.current_tenant.visible_domains, options).collect do |domain|
      object_from_ae_object(domain.fqname, domain)
    end
  end

  def find_base_object(path, options)
    parts = path.split('/').select { |p| p != "" }
    object = find_domain(parts[0], options)
    parts[1..-1].each { |part| object = children(object, options).find { |obj| part.casecmp(obj.ae_object.name) == 0 } }
    object
  end

  def find_domain(domain_name, options)
    domain = domains(options).find { |d| domain_name.casecmp(d[:ae_object].name) == 0 }
    raise "Invalid Automate Domain #{domain_name} specified" if domain.blank?
    domain
  end

  def children(object, options = {})
    return [] unless object
    filter_ae_objects(ae_children(object.ae_object), options).collect do |ae_object|
      object_from_ae_object("#{object.fqname}/#{ae_object.name}", ae_object)
    end
  end

  def ae_children(ae_object)
    Array(ae_object.try(:ae_namespaces)) +
      Array(ae_object.try(:ae_classes)) +
      Array(ae_object.try(:ae_instances)) +
      Array(ae_object.try(:ae_methods))
  end

  def filter_ae_objects(ae_objects, options)
    return ae_objects unless options[:state_machines]
    ae_objects.select do |obj|
      klass_name = obj.class.name
      if klass_name == "MiqAeInstance"
        true
      else
        prefix = klass_name == "MiqAeDomain" ? "MiqAeNamespace" : klass_name
        @waypoint_ids.include?("#{prefix}::#{obj.id}")
      end
    end
  end

  def object_from_ae_object(fqname, ae_object)
    domain_fqname = fqname[1..-1].sub(%r{^[^/]+}, '')
    domain_fqname = "/" if domain_fqname.blank?
    OpenStruct.new(:fqname => fqname, :domain_fqname => domain_fqname, :ae_object => ae_object)
  end
end
