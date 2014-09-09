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
      reftype = opts[:is_subcollection] ? "#{@req[:collection]}/#{@req[:c_id]}/#{type}" : type
      render :json => collection_to_jbuilder(type, reftype, resources, opts).target!
    end

    #
    # Helper proc to render a single resource
    #
    def render_resource(type, resource, opts = {})
      validate_response_format
      reftype = opts[:is_subcollection] ? "#{@req[:collection]}/#{@req[:c_id]}/#{type}" : type
      render :json => resource_to_jbuilder(type, reftype, resource, opts).target!
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
          add_hash json, resource_to_jbuilder(type, reftype, resource, opts).attributes!
        end
        aspecs = get_aspecs(type, opts[:collection_actions], :collection, opts[:is_subcollection], reftype)
      end
    end

    def resource_to_jbuilder(type, reftype, resource, opts = {})
      reftype = get_reftype(type, reftype, resource, opts)
      json    = Jbuilder.new
      json.ignore_nil!

      if resource.respond_to?(:attributes)
        json.href normalize_url_from_id(reftype, resource.id)
      elsif resource.is_a?(Hash)
        if resource.has_key?('results')
          resource['results'].each do |r|
            if r['href'].nil?
              r['href'] = normalize_url_from_id(reftype, r.id)
            end
          end
        end
      end

      add_hash json, normalize_hash(reftype, resource), :render_attr
      #
      # Let's expand subcollections for objects if asked for
      #
      scs = collection_config[type.to_sym]
      if resource.respond_to?(:attributes) && scs[:subcollections]
        scs[:subcollections].each do |sc|
          target = "#{sc}_query_resource"
          next unless respond_to?(target)
          next unless expand?(sc) || collection_config[sc.to_sym][:options].include?(:show)

          sctype = "#{type}/#{resource.id}/#{sc}"
          subresources = send(target, resource)

          expand_subcollection(json, sc, sctype, subresources)
        end
      end
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
    def add_hash(json, hash, attr_rendered = nil)
      return if hash.blank?
      hash.each do |attr, value|
        json.set! attr, value if attr_rendered.nil? || send(attr_rendered, attr)
      end
    end

    #
    # Return the deleted resource. 
    #
    def render_normal_destroy(type, res = {})
      render_resource type, res
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
      res = res.where(sqlfilter_param)            if sqlfilter_param
      res = res.reorder(sort_params)              if sort_params

      options = {
        :targets        => res,
        :userid         => @auth_user,
        :results_format => :objects
      }
      options[:offset], options[:limit] = expand_paginate_params if paginate_params?

      Rbac.search(options).first
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
              add_child js, normalize_hash(sctype, scr)
            end
            js.child! { |jsc| jsc.href normalize_url_from_id(sctype, scr["id"]) }
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
            if api_user_role_allows?(action[:identifier])
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
            if api_user_role_allows?(action[:identifier])
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
