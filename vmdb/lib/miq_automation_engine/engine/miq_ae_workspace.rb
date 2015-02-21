module MiqAeEngine
  class MiqAeWorkspace < ActiveRecord::Base
    serialize :workspace
    serialize :setters
    include UuidMixin

    def self.evmget(token, uri)
      MiqAeWorkspace.workspace_from_token(token).evmget(uri)
    end

    def evmget(uri)
      self.workspace.varget(uri)
    end

    def self.evmset(token, uri, value)
      MiqAeWorkspace.workspace_from_token(token).evmset(uri, value)
    end

    def evmset(uri, value)
      if self.workspace.varset(uri, value)
        self.setters ||= Array.new
        self.setters << [uri, value]
        self.save!
      end
    end

    private

    def self.workspace_from_token(token)
      ws = MiqAeWorkspace.find_by_guid(token)
      raise MiqAeException::WorkspaceNotFound, "Workspace Not Found for token=[#{token}]" if ws.nil?
      ws
    end

  end

  class MiqAeWorkspaceRuntime
    attr_accessor :graph, :num_drb_methods, :class_methods, :datastore_cache, :persist_state_hash
    attr_reader :nodes
    DEFAULTS = {
      :readonly => false
    }

    def initialize(options = {})
      options            = DEFAULTS.merge(options)
      @readonly          = options[:readonly]
      @nodes             = []
      @current           = Array.new
      @num_drb_methods   = 0
      @datastore_cache   = Hash.new
      @class_methods     = Hash.new
      @dom_search        = MiqAeDomainSearch.new
      @persist_state_hash = HashWithIndifferentAccess.new
    end

    def readonly?
      @readonly
    end

    def self.instantiate_readonly(uri, workspace = nil, root = nil)
      workspace ||= MiqAeWorkspaceRuntime.new(:readonly => true)
      self._instantiate(uri, workspace, root)
    end

    def self.instantiate(uri, workspace = nil, root = nil)
      workspace ||= MiqAeWorkspaceRuntime.new
      self._instantiate(uri, workspace, root)
    end

    def self._instantiate(uri, workspace, root)
      begin
        workspace.instantiate(uri, root)
      rescue MiqAeException
        return nil
      end
      return workspace
    end

    DATASTORE_CACHE = true
    def datastore(klass, key)
      if DATASTORE_CACHE
        @datastore_cache[klass]    ||= Hash.new
        @datastore_cache[klass][key] = yield      unless @datastore_cache[klass].has_key?(key)
        @datastore_cache[klass][key]
      else
        yield
      end
    end

    def varget(uri)
      obj = current_object
      raise MiqAeException::ObjectNotFound, "Current Object Not Found" if obj.nil?
      obj.uri2value(uri)
    end

    def varset(uri, value)
      scheme, userinfo, host, port, registry, path, opaque, query, fragment = MiqAeUri.split(uri)
      if scheme == "miqaews"
        o = get_obj_from_path(path)
        raise MiqAeException::ObjectNotFound, "Object Not Found for path=[#{path}]"  if o.nil?
        o[fragment] = value
        return true
      end
      return false
    end

    def instantiate(uri, root=nil)
      $miq_ae_logger.info("Instantiating [#{uri}]") if root.nil?

      scheme, userinfo, host, port, registry, path, opaque, query, fragment = MiqAeUri.split(uri, "miqaedb")
      raise "Unsupported Scheme [#{scheme}]" unless MiqAeUri.scheme_supported?(scheme)
      raise "Invalid URI <#{uri}>" if path.nil?

      message = fragment.blank? ? "create" : fragment.downcase
      args = MiqAeUri.query2hash(query)
      if (ae_state_data = args.delete('ae_state_data'))
        @persist_state_hash.merge!(YAML.load(ae_state_data))
      end

      ns, klass, instance = MiqAePath.split(path)
      ns = overlay_namespace(scheme, uri, ns, klass, instance)
      current = @current.last
      ns    ||= current[:ns]    if current
      klass ||= current[:klass] if current

      pushed = false
      raise MiqAeException::CyclicalRelationship, "cyclical reference: [#{MiqAeObject.fqname(ns, klass, instance)} with message=#{message}]" if cyclical?(ns, klass, instance, message)

      begin
        if scheme == "miqaedb"
          obj = MiqAeObject.new(self, ns, klass, instance)

          @current.push( {:ns => ns, :klass => klass, :instance => instance, :object => obj, :message => message} )
          pushed = true
          @nodes << obj
          link_parent_child(root, obj) if root

          obj.process_assertions(message)
          obj.process_args_as_attributes(args)
        elsif scheme == "miqaews"
          obj = get_obj_from_path(path)
          raise MiqAeException::ObjectNotFound, "Object [#{path}] not found" if obj.nil?
        elsif ["miqaemethod", "method"].include?(scheme)
          raise MiqAeException::MethodNotFound, "No Current Object" if current[:object].nil?
          return current[:object].process_method_via_uri(uri)
        end
        obj.process_fields(message)
      rescue MiqAeException::MiqAeDatastoreError => err
        $miq_ae_logger.error(err.message)
      rescue MiqAeException::AssertionFailure => err
        $miq_ae_logger.info(err.message)
        delete(obj)
      rescue MiqAeException::StopInstantiation => err
        $miq_ae_logger.info("Stopping instantiation because [#{err.message}]")
        delete(obj)
      rescue MiqAeException::AbortInstantiation => err
        $miq_ae_logger.info("Aborting instantiation because [#{err.message}]")
        raise
      rescue MiqAeException::UnknownMethodRc => err
        $miq_ae_logger.error("Aborting instantiation (unknown method return code) because [#{err.message}]")
        raise MiqAeException::AbortInstantiation, err.message
      ensure
        @current.pop if pushed
      end

      return obj
    end

    def to_expanded_xml(path=nil)
      objs = path.nil? ? roots : get_obj_from_path(path)
      objs = [objs] unless objs.kind_of?(Array)

      require 'builder'
      xml = Builder::XmlMarkup.new(:indent => 2)
      xml.MiqAeWorkspace {
        objs.each { |obj| obj.to_xml(:builder => xml) }
      }
    end

    def to_xml(path=nil)
      objs = path.nil? ? roots : get_obj_from_path(path)
      result = objs.collect { |obj| to_hash(obj) }.compact
      s = ""
      XmlHash.from_hash({"MiqAeObject" => result}, :rootname=>"MiqAeWorkspace").to_xml.write(s,2)
      return s
    end

    def to_dot(path=nil)
      require "rubygems"
      require "graphviz"

      objs = path.nil? ? roots : get_obj_from_path(path)

      g = GraphViz::new( "MiqAeWorkspace", :type => "digraph", :output => "dot")
      objs.each { |obj| obj_to_dot(g, obj) }
      s = g.output(:output => "none")
    end

    def obj_to_dot(g, obj)
      return nil if obj.nil?
      o = g.add_node(obj.object_name)
      # o["MiqAeClass"]     = obj.klass
      # o["MiqAeNamespace"] = obj.namespace
      # o["MiqAeInstance"]  = obj.instance
      # obj.attributes
      obj.children.each { |child|
        c = obj_to_dot(g, child)
        g.add_edge(o, c) unless c.nil?
      }
      return o
    end

    def to_hash(obj)
      result = {
        "namespace"   => obj.namespace,
        "class"       => obj.klass,
        "instance"    => obj.instance,
        "attributes"  => obj.attributes.delete_if {|k, v| v.nil?}.inspect,
        "MiqAeObject" => obj.children.collect { |c| to_hash(c) }
      }
      return result.delete_if {|k, v| v.nil?}
    end

    def cyclical?(ns, klass, instance, message)
      # check for cyclical references
      @current.each do |c|
        hash = { :ns => ns, :klass => klass, :instance => instance, :message => message }
        return true if hash.all? { |key, value| value.casecmp(c[key]).zero? rescue false }
      end
      return false
    end

    def current_object
      current(:object)
    end

    def current_message
      current(:message)
    end

    def current_namespace
      current(:ns)
    end

    def current_class
      current(:klass)
    end

    def current_instance
      current(:instance)
    end

    def current(elem = nil)
      c = @current.last
      return c if elem.nil? || c.nil?
      c[elem]
    end

    def push_method(name)
      current = @current.last.dup
      current[:method] = name
      @current.push(current)
    end

    def pop_method
      @current.pop
    end

    def current_method
      current(:method)
    end

    def root(attrib = nil)
      return nil if roots.empty?
      return roots.first if attrib.nil?
      roots.first.attributes[attrib.downcase]
    end

    def roots
      @nodes.reject(&:node_parent)
    end

    def get_obj_from_path(path)
      obj = current_object

      return obj if path.nil? || path.blank?

      path = path[1..-1] if path[0,2] == "/."

      if path == "/"
        return roots[0] if obj.nil?
        while true
          parent = obj.node_parent
          return obj if parent.nil?
          obj = parent
        end
      elsif path[0,1] == "."
        plist = path.split("/")
        until plist.empty? do
          part = plist.shift
          next if part.blank? || part == "."
          raise MiqAeException::InvalidPathFormat, "bad part [#{part}] in path [#{path}]" if (part != "..")
          obj = obj.node_parent
        end
      else
        obj = find_named_ancestor(path)
      end
      return obj
    end

    def find_named_ancestor(path)
      plist = path.split("/")
      raise MiqAeException::InvalidPathFormat, "Unsupported Path [#{path}]" if plist[0].blank?
      klass = plist.pop
      ns    = (plist.length == 0) ? "*" : plist.join('/')

      obj = current_object
      while(obj = obj.node_parent)
        next unless klass.casecmp(obj.klass).zero?
        break if ns == "*"
        ns_split = obj.namespace.split('/')
        ns_split.shift # sans domain
        break if ns.casecmp(ns_split.join('/')).zero?
      end
      return obj
    end

    def overlay_namespace(scheme, uri, ns, klass, instance)
      @dom_search.get_alternate_domain(scheme, uri, ns, klass, instance)
    end

    def overlay_method(ns, klass, method)
      @dom_search.get_alternate_domain_method('miqaedb', "#{ns}/#{klass}/#{method}", ns, klass, method)
    end

    private

    def delete(id)
      @nodes.delete(id)
      id.children.each { |node| node.node_parent = nil }
    end

    def link_parent_child(parent, child)
      parent.node_children << child
      child.node_parent = parent
    end
  end
end
