module Api
  class BaseController
    module Authentication
      #
      # REST APIs Authenticator and Redirector
      #
      def require_api_user_or_token
        log_request_initiated
        @auth_token = @auth_user = nil
        if request.headers['X-MIQ-Token']
          authenticate_with_system_token(request.headers['X-MIQ-Token'])
        elsif request.headers['X-Auth-Token']
          authenticate_with_user_token(request.headers['X-Auth-Token'])
        else
          authenticate_options = {
            :require_user => true,
            :timeout      => ::Settings.api.authentication_timeout.to_i_with_method
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
          :user_href  => "#{@req.api_prefix}/users/#{user.id}",
          :group      => group.description,
          :group_href => "#{@req.api_prefix}/groups/#{group.id}",
          :role       => group.miq_user_role_name,
          :role_href  => "#{@req.api_prefix}/roles/#{group.miq_user_role.id}",
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
        }.merge(@auth_user_obj.settings)
      end

      def userid_to_userobj(userid)
        User.lookup_by_identity(userid)
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

      private

      def product_features(role)
        pf_result = {}
        role.feature_identifiers.each { |ident| add_product_feature(pf_result, ident) }
        pf_result
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
        collection, method, action = collection_config.what_refers_to_feature(ident_str)
        collections = collection_config.names_for_feature(ident_str)
        res["href"] = "#{@req.api_prefix}/#{collections.first}" if collections.one?
        res["action"] = api_action_details(collection, method, action) if collection.present?
        res["children"] = children if children.present?
        pf_result[ident_str] = res
      end

      def api_action_details(collection, method, action)
        {
          "name"   => action[:name],
          "method" => method,
          "href"   => "#{@req.api_prefix}/#{collection}"
        }
      end

      def api_token_mgr
        Environment.user_token_service.token_mgr('api')
      end

      def authenticate_with_user_token(x_auth_token)
        @auth_token = x_auth_token
        if !api_token_mgr.token_valid?(@auth_token)
          raise AuthenticationError, "Invalid Authentication Token #{@auth_token} specified"
        else
          @auth_user     = api_token_mgr.token_get_info(@auth_token, :userid)
          @auth_user_obj = userid_to_userobj(@auth_user)

          unless request.headers['X-Auth-Skip-Token-Renewal'] == 'true'
            api_token_mgr.reset_token(@auth_token)
          end

          authorize_user_group(@auth_user_obj)
          validate_user_identity(@auth_user_obj)
          User.current_user = @auth_user_obj
        end
      end

      def authenticate_with_system_token(x_miq_token)
        @miq_token_hash = YAML.load(MiqPassword.decrypt(x_miq_token))

        validate_system_token_server(@miq_token_hash[:server_guid])
        validate_system_token_timestamp(@miq_token_hash[:timestamp])

        User.authorize_user(@miq_token_hash[:userid])

        @auth_user     = @miq_token_hash[:userid]
        @auth_user_obj = userid_to_userobj(@auth_user)

        authorize_user_group(@auth_user_obj)
        validate_user_identity(@auth_user_obj)
        User.current_user = @auth_user_obj
      rescue => err
        api_log_error("Authentication Failed with System Token\nX-MIQ-Token: #{x_miq_token}\nError: #{err}")
        raise AuthenticationError, "Invalid System Authentication Token specified"
      end

      def validate_system_token_server(server_guid)
        raise "Missing server_guid" if server_guid.blank?
        raise "Invalid server_guid #{server_guid} specified" unless MiqServer.where(:guid => server_guid).exists?
      end

      def validate_system_token_timestamp(timestamp)
        raise "Missing timestamp" if timestamp.blank?
        raise "Invalid timestamp #{timestamp} specified" if 5.minutes.ago.utc > timestamp
      end
    end
  end
end
