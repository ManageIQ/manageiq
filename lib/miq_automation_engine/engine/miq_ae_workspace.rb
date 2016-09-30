require_relative 'miq_ae_state_info'
module MiqAeEngine
  class MiqAeWorkspace < ApplicationRecord
    serialize :workspace
    serialize :setters
    include UuidMixin

    def self.evmget(token, uri)
      workspace_from_token(token).evmget(uri)
    end

    def evmget(uri)
      workspace.varget(uri)
    end

    def self.evmset(token, uri, value)
      workspace_from_token(token).evmset(uri, value)
    end

    def evmset(uri, value)
      if workspace.varset(uri, value)
        self.setters ||= []
        self.setters << [uri, value]
        self.save!
      end
    end

    def self.workspace_from_token(token)
      ws = MiqAeWorkspace.find_by_guid(token)
      raise MiqAeException::WorkspaceNotFound, "Workspace Not Found for token=[#{token}]" if ws.nil?
      ws
    end
    private_class_method(:workspace_from_token)
  end

  class MiqAeWorkspaceRuntime
    attr_accessor :graph, :class_methods, :invoker
    attr_accessor :datastore_cache, :persist_state_hash, :current_state_info
    attr_accessor :ae_user
    include MiqAeStateInfo

    attr_reader :nodes

    def initialize(options = {})
      @readonly          = options[:readonly] || false
      @nodes             = []
      @current           = []
      @datastore_cache   = {}
      @class_methods     = {}
      @dom_search        = MiqAeDomainSearch.new
      @persist_state_hash = HashWithIndifferentAccess.new
      @current_state_info = {}
      @state_machine_objects = []
      @ae_user = nil
    end

    delegate :prepend_namespace=, :to =>  :@dom_search

    def readonly?
      @readonly
    end

    def self.instantiate(uri, user, attrs = {})
      User.current_user = user
      workspace = MiqAeWorkspaceRuntime.new(attrs)
      workspace.instantiate(uri, user, nil)
      workspace
    rescue MiqAeException
    end

    DATASTORE_CACHE = true
    def datastore(klass, key)
      if DATASTORE_CACHE
        @datastore_cache[klass] ||= {}
        @datastore_cache[klass][key] = yield      unless @datastore_cache[klass].key?(key)
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
      false
    end

    def instantiate(uri, user, root = nil)
      $miq_ae_logger.info("Instantiating [#{uri}]") if root.nil?
      @ae_user = user
      @dom_search.ae_user = user
      scheme, userinfo, host, port, registry, path, opaque, query, fragment = MiqAeUri.split(uri, "miqaedb")

      raise MiqAeException::InvalidPathFormat, "Unsupported Scheme [#{scheme}]" unless MiqAeUri.scheme_supported?(scheme)
      raise MiqAeException::InvalidPathFormat, "Invalid URI <#{uri}>" if path.nil?

      message = fragment.blank? ? "create" : fragment.downcase
      args = MiqAeUri.query2hash(query)
      if (ae_state_data = args.delete('ae_state_data'))
        @persist_state_hash.merge!(YAML.load(ae_state_data))
      end

      if (ae_state_previous = args.delete('ae_state_previous'))
        load_previous_state_info(ae_state_previous)
      end

      ns, klass, instance = MiqAePath.split(path)
      ns = overlay_namespace(scheme, uri, ns, klass, instance)
      current = @current.last
      ns ||= current[:ns]    if current
      klass ||= current[:klass] if current

      pushed = false
      raise MiqAeException::CyclicalRelationship, "cyclical reference: [#{MiqAeObject.fqname(ns, klass, instance)} with message=#{message}]" if cyclical?(ns, klass, instance, message)

      begin
        if scheme == "miqaedb"
          obj = MiqAeObject.new(self, ns, klass, instance)

          @current.push({:ns => ns, :klass => klass, :instance => instance, :object => obj, :message => message})
          pushed = true
          @nodes << obj
          link_parent_child(root, obj) if root

          if obj.state_machine?
            save_current_state_info(@state_machine_objects.last) unless @state_machine_objects.empty?
            @state_machine_objects.push(obj.object_name)
            reset_state_info(obj.object_name)
          end

          obj.process_assertions(message)
          obj.process_args_as_attributes(args)
          obj.user_info_attributes(@ae_user) unless root
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
      rescue MiqAeException::UnknownMethodRc => err
        $miq_ae_logger.error("Aborting instantiation (unknown method return code) because [#{err.message}]")
        raise
      rescue MiqAeException::AbortInstantiation => err
        $miq_ae_logger.info("Aborting instantiation because [#{err.message}]")
        raise
      ensure
        @current.pop if pushed
        pop_state_machine_info if obj && obj.state_machine? && self.root
      end

      obj
    end

    def pop_state_machine_info
      last_state_machine = @state_machine_objects.pop
      case root['ae_result']
      when 'ok' then
        @current_state_info.delete(last_state_machine)
      when 'retry' then
        save_current_state_info(last_state_machine)
      end
      reset_state_info(@state_machine_objects.last) unless @state_machine_objects.empty?
    end

    def to_expanded_xml(path = nil)
      objs = path.nil? ? roots : get_obj_from_path(path)
      objs = [objs] unless objs.kind_of?(Array)

      require 'builder'
      xml = Builder::XmlMarkup.new(:indent => 2)
      xml.MiqAeWorkspace do
        objs.each { |obj| obj.to_xml(:builder => xml) }
      end
    end

    def to_xml(path = nil)
      objs = path.nil? ? roots : get_obj_from_path(path)
      result = objs.collect { |obj| to_hash(obj) }.compact
      s = ""
      XmlHash.from_hash({"MiqAeObject" => result}, :rootname => "MiqAeWorkspace").to_xml.write(s, 2)
      s
    end

    def to_dot(path = nil)
      require "rubygems"
      require "graphviz"

      objs = path.nil? ? roots : get_obj_from_path(path)

      g = GraphViz.new("MiqAeWorkspace", :type => "digraph", :output => "dot")
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
      obj.children.each do |child|
        c = obj_to_dot(g, child)
        g.add_edge(o, c) unless c.nil?
      end
      o
    end

    def to_hash(obj)
      result = {
        "namespace"   => obj.namespace,
        "class"       => obj.klass,
        "instance"    => obj.instance,
        "attributes"  => obj.attributes.delete_if { |_k, v| v.nil? }.inspect,
        "MiqAeObject" => obj.children.collect { |c| to_hash(c) }
      }
      result.delete_if { |_k, v| v.nil? }
    end

    def cyclical?(ns, klass, instance, message)
      # check for cyclical references
      @current.each do |c|
        hash = {:ns => ns, :klass => klass, :instance => instance, :message => message}
        return true if hash.all? { |key, value| value.casecmp(c[key]).zero? rescue false }
      end
      false
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

      path = path[1..-1] if path[0, 2] == "/."

      if path == "/"
        return roots[0] if obj.nil?
        loop do
          parent = obj.node_parent
          return obj if parent.nil?
          obj = parent
        end
      elsif path[0, 1] == "."
        plist = path.split("/")
        until plist.empty?
          part = plist.shift
          next if part.blank? || part == "."
          raise MiqAeException::InvalidPathFormat, "bad part [#{part}] in path [#{path}]" if (part != "..")
          obj = obj.node_parent
        end
      else
        obj = find_named_ancestor(path)
      end
      obj
    end

    def find_named_ancestor(path)
      plist = path.split("/")
      raise MiqAeException::InvalidPathFormat, "Unsupported Path [#{path}]" if plist[0].blank?
      klass = plist.pop
      ns    = (plist.length == 0) ? "*" : plist.join('/')

      obj = current_object
      while (obj = obj.node_parent)
        next unless klass.casecmp(obj.klass).zero?
        break if ns == "*"
        ns_split = obj.namespace.split('/')
        ns_split.shift # sans domain
        break if ns.casecmp(ns_split.join('/')).zero?
      end
      obj
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
