class ApiController
  module Authentication
    #
    # Action Methods
    #

    def show_auth
      requester_type = fetch_and_validate_requester_type
      auth_token = @api_token_mgr.gen_token(@module,
                                            :userid           => @auth_user,
                                            :token_ttl_config => REQUESTER_TTL_CONFIG[requester_type])
      res = {
        :auth_token => auth_token,
        :token_ttl  => @api_token_mgr.token_get_info(@module, auth_token, :token_ttl),
        :expires_on => @api_token_mgr.token_get_info(@module, auth_token, :expires_on)
      }
      render_resource :auth, res
    end

    def destroy_auth
      @api_token_mgr.invalidate_token(@module, @auth_token)

      render_normal_destroy
    end

    #
    # REST APIs Authenticator and Redirector
    #
    def require_api_user_or_token
      log_request_initiated
      @auth_token = @auth_user = nil
      if request.headers['X-Auth-Token']
        @auth_token  = request.headers['X-Auth-Token']
        if !@api_token_mgr.token_valid?(@module, @auth_token)
          raise AuthenticationError, "Invalid Authentication Token #{@auth_token} specified"
        else
          @auth_user     = @api_token_mgr.token_get_info(@module, @auth_token, :userid)
          @auth_user_obj = userid_to_userobj(@auth_user)

          unless request.headers['X-Auth-Skip-Token-Renewal'] == 'true'
            @api_token_mgr.reset_token(@module, @auth_token)
          end

          authorize_user_group(@auth_user_obj)
          validate_user_identity(@auth_user_obj)
          User.current_user = @auth_user_obj
        end
      else
        authenticate_options = {
          :require_user => true,
          :timeout      => @api_config[:authentication_timeout].to_i_with_method
        }

        if (user = authenticate_with_http_basic { |u, p| User.authenticate(u, p, request, authenticate_options) })
          @auth_user     = user.userid
          @auth_user_obj = userid_to_userobj(@auth_user)
          authorize_user_group(@auth_user_obj)
          validate_user_identity(@auth_user_obj)
          User.current_user = @auth_user_obj
        else
          request_http_basic_authentication
        end
      end
      log_api_auth
    end

    def auth_identity
      user  = @auth_user_obj
      group = user.current_group
      {
        :userid     => user.userid,
        :name       => user.name,
        :user_href  => "#{@req[:api_prefix]}/users/#{user.id}",
        :group      => group.description,
        :group_href => "#{@req[:api_prefix]}/groups/#{group.id}",
        :role       => group.miq_user_role_name,
        :role_href  => "#{@req[:api_prefix]}/roles/#{group.miq_user_role.id}",
        :tenant     => group.tenant.name,
        :groups     => user.miq_groups.pluck(:description),
      }
    end

    def auth_authorization
      user  = @auth_user_obj
      group = user.current_group
      {
        :product_features => product_features(group.miq_user_role)
      }
    end

    def user_settings
      {
        :locale => I18n.locale.to_s.sub('-', '_'),
      }
    end

    def userid_to_userobj(userid)
      User.find_by_userid(userid)
    end

    def authorize_user_group(user_obj)
      group_name = request.headers['X-MIQ-Group']
      if group_name.present?
        group_obj = user_obj.miq_groups.find_by_description(group_name)
        raise AuthenticationError, "Invalid Authorization Group #{group_name} specified" if group_obj.nil?
        user_obj.current_group_by_description = group_name
      end
    end

    def validate_user_identity(user_obj)
      @user_validation_service ||= UserValidationService.new(self)
      missing_feature = @user_validation_service.missing_user_features(user_obj)
      if missing_feature
        raise AuthenticationError, "Invalid User #{user_obj.userid} specified, User's #{missing_feature} is missing"
      end
    end

    def fetch_and_validate_requester_type
      requester_type = params['requester_type']
      return unless requester_type
      REQUESTER_TTL_CONFIG.fetch(requester_type) do
        requester_types = REQUESTER_TTL_CONFIG.keys.join(', ')
        raise BadRequestError, "Invalid requester_type #{requester_type} specified, valid types are: #{requester_types}"
      end
      requester_type
    end

    private

    def product_features(role)
      pf_result = {}
      role.feature_identifiers.each { |ident| add_product_feature(pf_result, ident) }
      pf_result
    end

    def product_settings
      VMDB::Config.new("vmdb").config[:product]
    end

    def add_product_feature(pf_result, ident)
      details  = MiqProductFeature.features[ident.to_s][:details]
      children = MiqProductFeature.feature_children(ident)
      add_product_feature_details(pf_result, ident, details, children)
      children.each { |child_ident| add_product_feature(pf_result, child_ident) }
    end

    def add_product_feature_details(pf_result, ident, details, children)
      ident_str = ident.to_s
      res = {
        "name"        => details[:name],
        "description" => details[:description]
      }
      collection, method, action = referenced_identifiers[ident_str]
      hrefs = get_hrefs_for_identifier(ident_str)
      res["href"] = hrefs.first if hrefs.one?
      res["action"] = api_action_details(collection, method, action) if collection.present?
      res["children"] = children if children.present?
      pf_result[ident_str] = res
    end

    def api_action_details(collection, method, action)
      {
        "name"   => action[:name],
        "method" => method,
        "href"   => "#{@req[:api_prefix]}/#{collection}"
      }
    end

    def referenced_identifiers
      @referenced_identifiers ||= begin
        identifiers = {}
        collection_config.each do |collection, cspec|
          next unless cspec[:collection_actions].present?
          cspec[:collection_actions].each do |method, action_definitions|
            next unless action_definitions.present?
            action_definitions.each do |action|
              identifier = action[:identifier]
              next if action[:disabled] || identifiers.key?(identifier)
              identifiers[identifier] = [collection, method, action]
            end
          end
        end
        identifiers
      end
    end

    def get_hrefs_for_identifier(identifier)
      @collection_hrefs ||= generate_collection_hrefs
      @collection_hrefs[identifier]
    end

    def generate_collection_hrefs
      collection_config.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(collection, cspec), result|
        ident = cspec[:identifier]
        next unless ident
        href = "#{@req[:api_prefix]}/#{collection}"
        result[ident] << href
      end
    end
  end
end
