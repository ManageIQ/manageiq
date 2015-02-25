module ApiHelper
  module Renderer
    #
    # Helper proc for rendering a collection of type specified.
    #
    def render_collection_type(type, id, is_subcollection = false)
      cspec = collection_config[type]
      klass = cspec[:klass].constantize
      opts  = {
        :name               => type.to_s,
        :is_subcollection   => is_subcollection,
        :resource_actions   => "resource_actions_#{type}",
        :collection_actions => "collection_actions_#{type}"
      }
      if id
        render_resource type, resource_search(id, type, klass), opts
      else
        opts[:count]            = klass.count
        opts[:expand_resources] = expand?(:resources)

        res = collection_search(is_subcollection, type, klass)

        opts[:subcount] = res.length

        render_collection type, res, opts
      end
    end

    #
    # Helper proc to render a collection
    #
    def render_collection(type, resources, opts = {})
      validate_response_format
      render :json => collection_to_jbuilder(type, gen_reftype(type, opts), resources, opts).target!
    end

    #
    # Helper proc to render a single resource
    #
    def render_resource(type, resource, opts = {})
      validate_response_format
      render :json => resource_to_jbuilder(type, gen_reftype(type, opts), resource, opts).target!
    end

    #
    # We want reftype to reflect subcollection if targeting as such.
    #
    def gen_reftype(type, opts)
      opts[:is_subcollection] ? "#{@req[:collection]}/#{@req[:c_id]}/#{type}" : type
    end

    # Methods for Serialization as Jbuilder Objects.

    #
    # Given a resource, return its serialized flavor using Jbuilder
    #
    def collection_to_jbuilder(type, reftype, resources, opts = {})
      Jbuilder.new do |json|
        json.ignore_nil!
        [:name, :count, :subcount].each do |opt_name|
          json.set! "#{opt_name}", opts[opt_name] if opts[opt_name]
        end
        json.resources resources.collect do |resource|
          if opts[:expand_resources]
            add_hash json, resource_to_jbuilder(type, reftype, resource, opts).attributes!
          else
            json.href normalize_href(reftype, resource["id"])
          end
        end
        aspecs = get_aspecs(type, opts[:collection_actions], :collection, opts[:is_subcollection], reftype)
        add_actions(json, aspecs, reftype)
      end
    end

    def resource_to_jbuilder(type, reftype, resource, opts = {})
      reftype = get_reftype(type, reftype, resource, opts)
      json    = Jbuilder.new
      json.ignore_nil!

      add_hash json, normalize_hash(reftype, resource, :add_href => true), :render_resource_attr, resource

      if resource.respond_to?(:attributes)
        expand_virtual_attributes(json, type, resource)
        expand_subcollections(json, type, resource)
      end

      expand_actions(json, type, opts)
      json
    end

    def get_reftype(type, reftype, resource, _opts = {})
      # sometimes we are returning different objects than the posted resource, i.e. request for an order.
      return reftype unless resource.respond_to?(:attributes)

      rclass = resource.class
      if collection_config.fetch_path(type.to_sym, :klass).constantize != rclass
        matched_type, _ = collection_config.detect do |_collection, spec|
          spec[:klass] && spec[:klass].constantize == rclass
        end
      end
      matched_type || reftype
    end

    #
    # type is the collection type we need to get actions specifications for
    # typed_actions is the optional type specific method to return actions
    # item_type is :collection or :resource
    # is_subcollection is true if accessing as subcollection or subresource
    # ref is how to identify item, either the reftype of the collection or href of resource
    #
    def get_aspecs(type, typed_actions, item_type, is_subcollection, ref)
      aspecs = []
      if typed_actions
        if respond_to?(typed_actions)
          aspecs = send(typed_actions, is_subcollection, ref)
        else
          aspecs = gen_action_specs(type, item_type, is_subcollection, ref)
        end
      end
      aspecs
    end

    #
    # Common proc for adding a child element to the Jbuilder
    #
    def add_child(json, hash)
      json.child! { |js| hash.each { |attr, value| js.set! attr, value } } unless hash.blank?
    end

    #
    # Common proc for adding a hash directly to the Jbuilder
    #
    def add_hash(json, hash, render_attr_proc = nil, resource = nil)
      return if hash.blank?
      hash.each do |attr, value|
        json.set! attr, value if render_attr_proc.nil? || send(render_attr_proc, resource, attr)
      end
    end

    #
    # Render nothing for normal resource deletes.
    #
    def render_normal_destroy
      render :nothing => true, :status => Rack::Utils.status_code(:no_content)
    end

    #
    # Render nothing for normal update.
    #
    def render_normal_update(type, res = {})
      render_resource type, res
    end

    #
    # Return the response format requested, i.e. :json or raise an error
    #
    def validate_response_format
      accept = request.headers["Accept"]
      return :json if accept.blank? || accept.include?("json") || accept.include?("*/*")
      raise ApiController::UnsupportedMediaTypeError, "Invalid Response Format #{accept} requested"
    end

    private

    def resource_search(id, type, klass)
      options = {
        :targets        => Array(klass.find(id)),
        :userid         => @auth_user,
        :results_format => :objects
      }
      res = Rbac.search(options).first.first
      raise ApiController::Forbidden, "Access to the resource #{type}/#{id} is forbidden" unless res
      res
    end

    def collection_search(is_subcollection, type, klass)
      res =
        if is_subcollection
          send("#{type}_query_resource", parent_resource_obj)
        elsif by_tag_param
          klass.find_tagged_with(:all => by_tag_param, :ns  => ApiController::TAG_NAMESPACE)
        else
          klass.scoped
        end
      filter_options = filter_param(klass)
      res = res.where(filter_options)             if filter_options.present? && res.respond_to?(:where)

      sort_options = sort_params(klass)
      res = res.reorder(sort_options)             if sort_options.present? && res.respond_to?(:reorder)

      options = {
        :targets        => res,
        :userid         => @auth_user,
        :results_format => :objects
      }
      options[:offset], options[:limit] = expand_paginate_params if paginate_params?

      Rbac.search(options).first
    end

    #
    # Let's expand subcollections for objects if asked for
    #
    def expand_subcollections(json, type, resource)
      scs = collection_config[type.to_sym][:subcollections]
      return unless scs
      scs.each do |sc|
        target = "#{sc}_query_resource"
        next unless expand_subcollection?(sc, target)
        expand_subcollection(json, sc, "#{type}/#{resource.id}/#{sc}", send(target, resource))
      end
    end

    def expand_subcollection?(sc, target)
      respond_to?(target) && (expand?(sc) || collection_config[sc.to_sym][:options].include?(:show))
    end

    #
    # Let's expand virtual attributes and related objects if asked for
    # Supporting [<related_object>]*.<virtual_attribute>
    #
    def expand_virtual_attributes(json, type, resource)
      result = {}
      object_hash = {}
      virtual_attributes_list(resource).each do |vattr|
        attr_name, attr_base = split_virtual_attribute(vattr)
        value, value_result = if attr_base.blank?
                                fetch_direct_virtual_attribute(type, resource, attr_name)
                              else
                                fetch_indirect_virtual_attribute(type, resource, attr_base, attr_name, object_hash)
                              end
        result = result.deep_merge(value_result) unless value.nil?
      end
      add_hash json, result
    end

    def fetch_direct_virtual_attribute(_type, resource, attr)
      return unless attr_accessible?(resource, attr)
      value = resource.public_send(attr)
      result = {attr => normalize_virtual(nil, attr, value, :ignore_nil => true)}
      # set nil vtype above to "#{type}/#{resource.id}/#{attr}" to support id normalization
      [value, result]
    end

    def fetch_indirect_virtual_attribute(_type, resource, base, attr, object_hash)
      query_related_objects(base, resource, object_hash)
      return unless attr_accessible?(object_hash[base], attr)
      value = object_hash[base].public_send(attr)
      result = {attr => normalize_virtual(nil, attr, value, :ignore_nil => true)}
      # set nil vtype above to "#{type}/#{resource.id}/#{base.tr('.', '/')}/#{attr}" to support id normalization
      base.split(".").reverse.each { |level| result = {level => result} }
      [value, result]
    end

    #
    # Accesing and hashing <resource>[.<related_object>]+ in object_hash
    #
    def query_related_objects(object_path, resource, object_hash)
      return if object_hash[object_path].present?
      related_resource = resource
      related_objects  = []
      object_path.split(".").each do |related_object|
        related_objects << related_object
        if attr_accessible?(related_resource, related_object)
          related_resource = related_resource.public_send(related_object)
          object_hash[related_objects.join(".")] = related_resource if related_resource
        end
      end
    end

    #
    # Let's get a list of virtual attributes applicable to the resource.
    #
    def virtual_attributes_list(resource)
      return [] if attribute_selection == "all"
      attribute_selection.collect do |requested_attr|
        requested_attr if attr_virtual?(resource, requested_attr)
      end.compact
    end

    def split_virtual_attribute(attr)
      attr_parts = attr_split(attr)
      return [attr_parts.first, ""] if attr_parts.length == 1
      [attr_parts.last, attr_parts[0..-2].join(".")]
    end

    def attr_accessible?(object, attr)
      return false unless object && object.respond_to?(attr)
      is_reflection = object.class.reflections_with_virtual.keys.collect(&:to_s).include?(attr)
      is_column = object.class.columns_hash_with_virtual.keys.include?(attr) unless is_reflection
      is_reflection || is_column
    end

    def attr_virtual?(object, attr)
      primary = attr_split(attr).first
      return false unless object && object.respond_to?(:attributes) && object.respond_to?(primary)
      is_reflection = object.class.reflections_with_virtual.keys.collect(&:to_s).include?(primary)
      is_virtual_column = object.class.virtual_columns_hash.keys.include?(primary) unless is_reflection
      is_reflection || is_virtual_column
    end

    def attr_split(attr)
      attr.tr("/", ".").split(".")
    end

    #
    # Let's expand actions
    #
    def expand_actions(json, type, opts)
      return unless render_attr("actions")

      href   = json.attributes!["href"]
      aspecs = get_aspecs(type, opts[:resource_actions], :resource, opts[:is_subcollection], href)
      add_actions(json, aspecs, type)
    end

    def add_actions(json, aspecs, type)
      if aspecs && aspecs.size > 0
        json.actions do |js|
          aspecs.each { |action_spec| add_child js, normalize_hash(type, action_spec) }
        end
      end
    end

    def render_resource_attr(resource, attr)
      pas = physical_attribute_selection(resource)
      pas.blank? || pas.include?(attr)
    end

    def physical_attribute_selection(resource)
      return [] unless params['attributes']
      physical_attributes = params['attributes'].split(",").collect do |attr|
        attr unless attr_virtual?(resource, attr)
      end.compact
      physical_attributes.present? ? physical_attributes | ApiController::ID_ATTRS : []
    end

    #
    # Let's expand a subcollection
    #
    def expand_subcollection(json, sc, sctype, subresources)
      if collection_config[sc.to_sym][:options].include?(:show_as_collection)
        copts = {
          :count            => subresources.length,
          :is_subcollection => true,
          :expand_resources => expand?(sc.to_s)
        }
        json.set! sc.to_s, collection_to_jbuilder(sc.to_sym, sctype, subresources, copts)
      else
        json.set! sc.to_s do |js|
          subresources.each do |scr|
            if expand?(sc) || scr["id"].nil?
              add_child js, normalize_hash(sctype, scr, :add_href => true)
            else
              js.child! { |jsc| jsc.href normalize_href(sctype, scr["id"]) }
            end
          end
        end
      end
    end

    #
    # Let's create the action specs for the different collections
    #
    # type is :collection or :resource
    # subcollection set to true, if accessing collection or resource as subcollection
    # href is the optional href for the action specs, required for resources
    #
    def gen_action_specs(collection, type, is_subcollection, href = nil)
      if collection_config.key?(collection)
        cspec = collection_config[collection]
        if type == :collection
          gen_action_spec_for_collections(collection, cspec, is_subcollection, href)
        else
          gen_action_spec_for_resources(cspec, is_subcollection, href)
        end
      end
    end

    def gen_action_spec_for_collections(collection, cspec, is_subcollection, href)
      target = is_subcollection ? :subcollection_actions : :collection_actions
      return [] unless cspec.key?(target)
      cspec[target].each.collect do |method, action_definitions|
        if cspec[:methods].include?(method)
          action_definitions.each.collect do |action|
            if !action[:disabled] && api_user_role_allows?(action[:identifier])
              {"name" => action[:name], "method" => method, "href" => (href ? href : collection)}
            end
          end
        end
      end.flatten.compact
    end

    def gen_action_spec_for_resources(cspec, is_subcollection, href)
      target = is_subcollection ? :subresource_actions : :resource_actions
      return [] unless cspec.key?(target)
      cspec[target].each.collect do |method, action_definitions|
        if cspec[:methods].include?(method)
          action_definitions.each.collect do |action|
            if !action[:disabled] && api_user_role_allows?(action[:identifier])
              {"name" => action[:name], "method" => method, "href" => href}
            end
          end
        end
      end.flatten.compact
    end

    def api_user_role_allows?(action_identifier)
      return true unless action_identifier
      @auth_user_obj.role_allows?(:identifier => action_identifier)
    end
  end
end
