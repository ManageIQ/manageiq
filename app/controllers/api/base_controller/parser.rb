module Api
  class BaseController
    module Parser
      def parse_api_request
        @req = RequestAdapter.new(request, params)
      end

      def validate_api_request
        validate_optional_collection_classes

        # API Version Validation
        if @req.version
          vname = @req.version
          unless version_config[:definitions].collect { |vent| vent[:name] }.include?(vname)
            raise BadRequestError, "Unsupported API Version #{vname} specified"
          end
        end

        cname, ctype = validate_api_request_collection
        cname, ctype = validate_api_request_subcollection(cname, ctype)

        # Method Validation for the collection or sub-collection specified
        if cname && ctype
          mname = @req.method
          unless collection_config.supports_http_method?(cname, mname)
            raise BadRequestError, "Unsupported HTTP Method #{mname} for the #{ctype} #{cname} specified"
          end
        end

        validate_api_parameters
      end

      def validate_optional_collection_classes
        @collection_klasses = {}  # Default all to config classes
        param = params['provider_class']
        return unless param.present?

        raise BadRequestError, "Unsupported provider_class #{param} specified" if param != "provider"
        %w(tags policies policy_profiles).each do |cname|
          if @req.subcollection == cname || @req.expand?(cname)
            raise BadRequestError, "Management of #{cname} is unsupported for the Provider class"
          end
        end
        @collection_klasses[:providers] = Provider
      end

      def validate_api_action
        return unless @req.collection
        send("validate_#{@req.method}_method")
      end

      def validate_api_parameters
        return unless params['sqlfilter']

        raise BadRequestError, "The sqlfilter parameter is no longer supported, please use the filter parameter instead"
      end

      #
      # Given an HREF, return the related collection,id pair
      # or subcollection,id pair if it represents a subcollection.
      #   [http://.../api[/v#.#]]/<collection>/<c_id>
      #   [http://.../api[/v#.#]]/collection/c_id/<subcollection>/<s_id>
      #
      #   [/api/v#.#]/<collection>/<c_id>
      #   [/api/v#.#]/collection/c_id/<subcollection>/<s_id>
      #
      #   <collection>/<c_id>
      #   collection/c_id/<subcollection>/<s_id>
      #
      def parse_href(href)
        if href
          path = href.match(/^http/) ? URI.parse(href).path.sub(/\/*$/, '') : href
          path = "#{@prefix}/#{path}" unless path.match(@prefix)
          path = path.sub(/\/*$/, '')
          return href_collection_id(path)
        end
        [nil, nil]
      end

      def href_collection_id(path)
        path_array = path.split('/')
        cidx = path_array[2] && path_array[2].match(version_config[:regex]) ? 3 : 2

        collection, c_id    = path_array[cidx..cidx + 1]
        subcollection, s_id = path_array[cidx + 2..cidx + 3]

        subcollection ? [subcollection.to_sym, from_cid(s_id)] : [collection.to_sym, from_cid(c_id)]
      end

      def parse_id(resource, collection)
        return nil if resource.blank?

        href_id = href_id(resource["href"], collection)
        return from_cid(href_id) if href_id.present?

        resource["id"].kind_of?(Integer) ? resource["id"] : nil
      end

      def href_id(href, collection)
        href.match(%r{^.*/#{collection}/([0-9r]+)$}) && Regexp.last_match(1) if href.present?
      end

      def parse_by_attr(resource, type, attr_list)
        klass = collection_class(type)
        objs = attr_list.map { |attr| klass.send("find_by_#{attr}", resource[attr]) if resource[attr] }.compact
        objs.collect(&:id).first
      end

      def parse_owner(resource)
        return nil if resource.blank?
        owner_id = parse_id(resource, :users)
        owner_id ? owner_id : parse_by_attr(resource, :users, %w(name userid))
      end

      def parse_group(resource)
        return nil if resource.blank?
        group_id = parse_id(resource, :groups)
        group_id ? group_id : parse_by_attr(resource, :groups, %w(description))
      end

      def parse_role(resource)
        return nil if resource.blank?
        role_id = parse_id(resource, :roles)
        role_id ? role_id : parse_by_attr(resource, :roles, %w(name))
      end

      def parse_tenant(resource)
        parse_id(resource, :tenants) unless resource.blank?
      end

      def fetch_provider(data)
        provider_id = parse_id(data, :providers)
        raise BadRequestError, 'Missing Provider identifier href or id' if provider_id.nil?
        resource_search(provider_id, :providers, collection_class(:providers))
      end

      def fetch_availability_zone(data)
        availability_zone_id = parse_id(data, :availability_zones)
        raise BadRequestError, 'Missing availability zone identifier href or id' if availability_zone_id.nil?
        resource_search(availability_zone_id, :availability_zones, collection_class(:availability_zones))
      end

      def parse_ownership(data)
        {
          :owner => collection_class(:users).find_by_id(parse_owner(data["owner"])),
          :group => collection_class(:groups).find_by_id(parse_group(data["group"]))
        }.compact if data.present?
      end

      # RBAC Aware type specific resource fetches

      def parse_fetch_group(data)
        if data
          group_id = parse_group(data)
          raise BadRequestError, "Missing Group identifier href, id or description" if group_id.nil?
          resource_search(group_id, :groups, collection_class(:groups))
        end
      end

      def parse_fetch_role(data)
        if data
          role_id = parse_role(data)
          raise BadRequestError, "Missing Role identifier href, id or name" if role_id.nil?
          resource_search(role_id, :roles, collection_class(:roles))
        end
      end

      def parse_fetch_tenant(data)
        if data
          tenant_id = parse_tenant(data)
          raise BadRequestError, "Missing Tenant identifier href or id" if tenant_id.nil?
          resource_search(tenant_id, :tenants, collection_class(:tenants))
        end
      end

      private

      #
      # For Posts we need to support actions, let's validate those
      #
      def validate_post_method
        cname = @req.subcollection || @req.collection
        type, target = request_type_target
        validate_post_api_action(cname, @req.method, type, target)
      end

      #
      # For Get, Delete, Patch and Put, we need to make sure we're entitled for them.
      #
      def validate_get_method
        validate_method_action(:get, "read")
      end

      def validate_patch_method
        validate_method_action(:post, "edit")
      end

      def validate_put_method
        validate_method_action(:post, "edit")
      end

      def validate_delete_method
        validate_method_action(:delete, "delete")
      end

      def validate_method_action(method_name, action_name)
        cname, target = if collection_option?(:arbitrary_resource_path)
                          [@req.collection, (@req.c_id ? :resource : :collection)]
                        else
                          [@req.subcollection || @req.collection, request_type_target.last]
                        end
        aspec = collection_config.typed_collection_actions(cname, target)
        return if method_name == :get && aspec.nil?
        action_hash = fetch_action_hash(aspec, method_name, action_name)
        raise BadRequestError, "Disabled action #{action_name}" if action_hash[:disabled]
        unless api_user_role_allows?(action_hash[:identifier])
          raise Forbidden, "Use of the #{action_name} action is forbidden"
        end
      end

      def request_type_target
        if @req.subcollection
          @req.s_id ? [:resource, :subresource] : [:collection, :subcollection]
        else
          @req.c_id ? [:resource, :resource] : [:collection, :collection]
        end
      end

      def validate_post_api_action(cname, mname, type, target)
        aname = @req.action

        aspec = collection_config.typed_collection_actions(cname, target)
        raise BadRequestError, "No actions are supported for #{cname} #{type}" unless aspec

        action_hash = fetch_action_hash(aspec, mname, aname)
        if action_hash.blank?
          unless type == :resource && collection_config.custom_actions?(cname)
            raise BadRequestError, "Unsupported Action #{aname} for the #{cname} #{type} specified"
          end
        end

        if action_hash.present?
          raise BadRequestError, "Disabled Action #{aname} for the #{cname} #{type} specified" if action_hash[:disabled]
          raise Forbidden, "Use of Action #{aname} is forbidden" unless api_user_role_allows?(action_hash[:identifier])
        end

        validate_post_api_action_as_subcollection(cname, mname, aname)
      end

      def validate_api_request_collection
        # Collection Validation
        if @req.collection
          cname = @req.collection
          ctype = "Collection"
          raise BadRequestError, "Unsupported #{ctype} #{cname} specified" unless collection_config[cname]
          if collection_config.primary?(cname)
            if "#{@req.c_id}#{@req.subcollection}#{@req.s_id}".present?
              raise BadRequestError, "Invalid request for #{ctype} #{cname} specified"
            end
          else
            raise BadRequestError, "Unsupported #{ctype} #{cname} specified" unless collection_config.collection?(cname)
          end
          [cname, ctype]
        end
      end

      def validate_api_request_subcollection(cname, ctype)
        # Sub-Collection Validation for the specified Collection
        if cname && @req.subcollection
          return [cname, ctype] if collection_option?(:arbitrary_resource_path)
          ctype = "Sub-Collection"
          unless collection_config.subcollection?(cname, @req.subcollection)
            raise BadRequestError, "Unsupported #{ctype} #{@req.subcollection} specified"
          end
          cname = @req.subcollection
        end
        [cname, ctype]
      end

      def validate_post_api_action_as_subcollection(cname, mname, aname)
        return if cname == @req.collection
        return if collection_config.subcollection_denied?(@req.collection, cname)

        aspec = collection_config.typed_subcollection_actions(@req.collection, cname)
        return unless aspec

        action_hash = fetch_action_hash(aspec, mname, aname)
        raise BadRequestError, "Unsupported Action #{aname} for the #{cname} sub-collection" if action_hash.blank?
        raise BadRequestError, "Disabled Action #{aname} for the #{cname} sub-collection" if action_hash[:disabled]

        unless api_user_role_allows?(action_hash[:identifier])
          raise Forbidden, "Use of Action #{aname} for the #{cname} sub-collection is forbidden"
        end
      end

      def fetch_action_hash(aspec, method_name, action_name)
        Array(aspec[method_name]).detect { |h| h[:name] == action_name } || {}
      end

      def collection_option?(option)
        collection_config.option?(@req.collection, option) if @req.collection
      end

      def assert_id_not_specified(data, type)
        if data.key?('id') || data.key?('href')
          raise BadRequestError, "Resource id or href should not be specified for creating a new #{type}"
        end
      end
    end
  end
end
