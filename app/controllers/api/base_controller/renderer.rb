module Api
  class BaseController
    module Renderer
      #
      # Helper proc to render a collection
      #
      def render_collection(type, resources, opts = {})
        render :json => collection_to_jbuilder(type, gen_reftype(type, opts), resources, opts).target!
      end

      #
      # Helper proc to render a single resource
      #
      def render_resource(type, resource, opts = {})
        render :json => resource_to_jbuilder(type, gen_reftype(type, opts), resource, opts).target!
      end

      #
      # We want reftype to reflect subcollection if targeting as such.
      #
      def gen_reftype(type, opts)
        opts[:is_subcollection] ? "#{@req.collection}/#{@req.c_id}/#{type}" : type
      end

      # Methods for Serialization as Jbuilder Objects.

      #
      # Given a resource, return its serialized flavor using Jbuilder
      #
      def collection_to_jbuilder(type, reftype, resources, opts = {})
        Jbuilder.new do |json|
          json.ignore_nil!
          [:name, :count, :subcount].each do |opt_name|
            json.set! opt_name.to_s, opts[opt_name] if opts[opt_name]
          end
          unless @req.hide?("resources")
            json.resources resources.collect do |resource|
              if opts[:expand_resources]
                add_hash json, resource_to_jbuilder(type, reftype, resource, opts).attributes!
              else
                json.href normalize_href(reftype, resource["id"])
              end
            end
          end
          cspec = collection_config[type]
          aspecs = gen_action_spec_for_collections(type, cspec, opts[:is_subcollection], reftype) if cspec
          add_actions(json, aspecs, reftype)
        end
      end

      def resource_to_jbuilder(type, reftype, resource, opts = {})
        reftype = get_reftype(type, reftype, resource, opts)
        json    = Jbuilder.new
        json.ignore_nil!

        normalize_options = {:add_href => true}

        pas = physical_attribute_selection(resource)
        normalize_options[:render_attributes] = pas if pas.present?

        add_hash json, normalize_hash(reftype, resource, normalize_options), :render_resource_attr, resource

        if resource.respond_to?(:attributes)
          expand_virtual_attributes(json, type, resource)
          expand_subcollections(json, type, resource)
        end

        expand_actions(resource, json, type, opts) if opts[:expand_actions]
        expand_resource_custom_actions(resource, json, type)
        json
      end

      def get_reftype(type, reftype, resource, _opts = {})
        # sometimes we are returning different objects than the posted resource, i.e. request for an order.
        return reftype unless resource.respond_to?(:attributes)

        rclass = resource.class
        collection_class = collection_class(type)

        # Ensures hrefs are consistent with those of the collection they were requested from
        return reftype if collection_class == rclass || collection_class.descendants.include?(rclass)

        collection_config.name_for_klass(rclass) || reftype
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
        head :no_content
      end

      #
      # Render nothing for normal update.
      #
      def render_normal_update(type, res = {})
        render_resource type, res
      end

      #
      # Method name for optional accessor of virtual attributes
      #
      def virtual_attribute_accessor(type, attr)
        method = "fetch_#{type}_#{attr}"
        respond_to?(method) ? method : nil
      end

      private

      def resource_search(id, type, klass)
        validate_id(id, klass)
        target = respond_to?("find_#{type}") ? public_send("find_#{type}", id) : klass.find(id)
        res = Rbac.filtered_object(target, :user => User.current_user, :class => klass)
        raise ForbiddenError, "Access to the resource #{type}/#{id} is forbidden" unless res
        res
      end

      def collection_search(is_subcollection, type, klass)
        res =
          if is_subcollection
            send("#{type}_query_resource", parent_resource_obj)
          elsif by_tag_param
            klass.find_tagged_with(:all => by_tag_param, :ns => TAG_NAMESPACE)
          else
            klass.all
          end

        res = res.where(public_send("#{type}_search_conditions")) if respond_to?("#{type}_search_conditions")

        miq_expression = filter_param(klass)

        if miq_expression
          if is_subcollection && !res.respond_to?(:where)
            raise BadRequestError, "Filtering is not supported on #{type} subcollection"
          end
          sql, _, attrs = miq_expression.to_sql
          res = res.where(sql) if attrs[:supported_by_sql]
        end

        sort_options = sort_params(klass) if res.respond_to?(:reorder)
        res = res.reorder(sort_options) if sort_options.present?

        options = {:user => User.current_user}
        options[:order] = sort_options if sort_options.present?
        options[:offset], options[:limit] = expand_paginate_params if paginate_params?
        options[:filter] = miq_expression if miq_expression

        Rbac.filtered(res, options)
      end

      #
      # Let's expand subcollections for objects if asked for
      #
      def expand_subcollections(json, type, resource)
        collection_config.subcollections(type).each do |sc|
          target = "#{sc}_query_resource"
          next unless expand_subcollection?(sc, target)
          if Array(attribute_selection).include?(sc.to_s)
            raise BadRequestError, "Cannot expand subcollection #{sc} by name and virtual attribute"
          end
          expand_subcollection(json, sc, "#{type}/#{resource.id}/#{sc}", send(target, resource))
        end
      end

      def expand_subcollection?(sc, target)
        respond_to?(target) && (@req.expand?(sc) || collection_config.show?(sc))
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

      def fetch_direct_virtual_attribute(type, resource, attr)
        return unless attr_accessible?(resource, attr)
        virtattr_accessor = virtual_attribute_accessor(type, attr)
        value = virtattr_accessor.nil? ? resource.public_send(attr) : send(virtattr_accessor, resource)
        result = {attr => normalize_attr(attr, value)}
        # set nil vtype above to "#{type}/#{resource.id}/#{attr}" to support id normalization
        [value, result]
      end

      def fetch_indirect_virtual_attribute(_type, resource, base, attr, object_hash)
        query_related_objects(base, resource, object_hash)
        return unless attr_accessible?(object_hash[base], attr)
        value = object_hash[base].public_send(attr)
        result = {attr => normalize_attr(attr, value)}
        # set nil vtype above to "#{type}/#{resource.id}/#{base.tr('.', '/')}/#{attr}" to support id normalization
        base.split(".").reverse_each { |level| result = {level => result} }
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
        return true if object && object.respond_to?(attr)
        object.class.try(:has_attribute?, attr) ||
          object.class.try(:reflect_on_association, attr) ||
          object.class.try(:virtual_attribute?, attr) ||
          object.class.try(:virtual_reflection?, attr)
      end

      def attr_virtual?(object, attr)
        return false if ID_ATTRS.include?(attr)
        primary = attr_split(attr).first
        (object.class.respond_to?(:reflect_on_association) && object.class.reflect_on_association(primary)) ||
          (object.class.respond_to?(:virtual_attribute?) && object.class.virtual_attribute?(primary)) ||
          (object.class.respond_to?(:virtual_reflection?) && object.class.virtual_reflection?(primary))
      end

      def attr_physical?(object, attr)
        return true if ID_ATTRS.include?(attr)
        (object.class.respond_to?(:has_attribute?) && object.class.has_attribute?(attr)) &&
          !(object.class.respond_to?(:virtual_attribute?) && object.class.virtual_attribute?(attr))
      end

      def attr_split(attr)
        attr.tr("/", ".").split(".")
      end

      #
      # Let's expand actions
      #
      def expand_actions(resource, json, type, opts)
        return unless render_actions(resource)

        href = json.attributes!["href"]
        cspec = collection_config[type]
        aspecs = gen_action_spec_for_resources(cspec, opts[:is_subcollection], href, resource) if cspec
        add_actions(json, aspecs, type)
      end

      def add_actions(json, aspecs, type)
        if aspecs && aspecs.any?
          json.actions do |js|
            aspecs.each { |action_spec| add_child js, normalize_hash(type, action_spec) }
          end
        end
      end

      def expand_resource_custom_actions(resource, json, type)
        return unless render_actions(resource) && collection_config.custom_actions?(type)

        href = json.attributes!["href"]
        json.actions do |js|
          resource_custom_action_names(resource).each do |action|
            add_child js, "name" => action, "method" => :post, "href" => href
          end
        end
      end

      def resource_custom_action_names(resource)
        return [] unless resource.respond_to?(:custom_action_buttons)
        Array(resource.custom_action_buttons).collect(&:name).collect(&:downcase)
      end

      def render_resource_attr(resource, attr)
        pas = physical_attribute_selection(resource)
        pas.blank? || pas.include?(attr)
      end

      def physical_attribute_selection(resource)
        return [] if resource.kind_of?(Hash)
        physical_attributes = @req.attributes.select { |attr| attr_physical?(resource, attr) }
        physical_attributes.present? ? ID_ATTRS | physical_attributes : []
      end

      #
      # Let's expand a subcollection
      #
      def expand_subcollection(json, sc, sctype, subresources)
        if collection_config.show_as_collection?(sc)
          copts = {
            :count            => subresources.length,
            :is_subcollection => true,
            :expand_resources => @req.expand?(sc)
          }
          json.set! sc.to_s, collection_to_jbuilder(sc.to_sym, sctype, subresources, copts)
        else
          json.set! sc.to_s do |js|
            subresources.each do |scr|
              if @req.expand?(sc) || scr["id"].nil?
                add_child js, normalize_hash(sctype, scr, :add_href => true)
              else
                js.child! { |jsc| jsc.href normalize_href(sctype, scr["id"]) }
              end
            end
          end
        end
      end

      def gen_action_spec_for_collections(collection, cspec, is_subcollection, href)
        if is_subcollection
          target = :subcollection_actions
          cspec_target = cspec[target] || collection_config.typed_subcollection_actions(@req.collection, collection)
        else
          target = :collection_actions
          cspec_target = cspec[target]
        end
        return [] unless cspec_target
        cspec_target.each.collect do |method, action_definitions|
          next unless render_actions_for_method(cspec[:verbs], method)
          typed_action_definitions = fetch_typed_subcollection_actions(method, is_subcollection) || action_definitions
          typed_action_definitions.each.collect do |action|
            if !action[:disabled] && api_user_role_allows?(action[:identifier])
              {"name" => action[:name], "method" => method, "href" => (href ? href : collection)}
            end
          end
        end.flatten.compact
      end

      def gen_action_spec_for_resources(cspec, is_subcollection, href, resource)
        if is_subcollection
          target = :subresource_actions
          cspec_target = cspec[target] || collection_config.typed_subcollection_actions(@req.collection, @req.subcollection, :subresource)
        else
          target = :resource_actions
          cspec_target = cspec[target]
        end
        return [] unless cspec_target
        cspec_target.each.collect do |method, action_definitions|
          next unless render_actions_for_method(cspec[:verbs], method)
          typed_action_definitions = action_definitions || fetch_typed_subcollection_actions(method, is_subcollection)
          typed_action_definitions.each.collect do |action|
            if !action[:disabled] && api_user_role_allows?(action[:identifier]) && action_validated?(resource, action)
              {"name" => action[:name], "method" => method, "href" => href}
            end
          end
        end.flatten.compact
      end

      def render_actions_for_method(methods, method)
        method != :get && methods.include?(method)
      end

      def fetch_typed_subcollection_actions(method, is_subcollection)
        return unless is_subcollection
        collection_config.typed_subcollection_action(@req.collection, @req.subcollection, method)
      end

      def api_user_role_allows?(action_identifier)
        return true unless action_identifier
        Array(action_identifier).any? { |identifier| User.current_user.role_allows?(:identifier => identifier) }
      end

      def render_actions(resource)
        render_attr("actions") || physical_attribute_selection(resource).blank?
      end

      def action_validated?(resource, action_spec)
        if action_spec[:options] && action_spec[:options].include?(:validate_action)
          validate_method = "validate_#{action_spec[:name]}"
          return resource.respond_to?(validate_method) && resource.send(validate_method)
        end
        true
      end

      def render_options(resource, data = {})
        klass = collection_class(resource)
        render :json => OptionsSerializer.new(klass, data).serialize
      end
    end
  end
end
