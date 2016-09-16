module Spec
  module Support
    module AuthHelper
      def http_login(username = 'username', password = 'password')
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
      end

      def login_as(user)
        User.current_user = user
        session[:userid]  = user.userid
        session[:group]   = user.current_group_id
        user
      end

      # TODO: Stub specific features, document use
      def stub_user(features:)
        user = FactoryGirl.build(:user_with_group)
        allow(controller).to receive(:current_user).and_return(user)
        allow(User).to receive(:current_user).and_return(user)
        allow(User).to receive(:server_timezone).and_return("UTC")
        allow_any_instance_of(described_class).to receive(:set_user_time_zone)

        stub_bool = case features
                    when :all  then true
                    when :none then false
                    else
                      raise ArgumentError, <<-EOS
      Unknown features option. You must pass :all or :none to #stub_user.
      If you need specific features, use #login_as with an actual User model instead.
                      EOS
                    end
        allow(controller).to receive(:check_privileges).and_return(stub_bool)
        allow(Rbac).to receive(:role_allows?).and_return(stub_bool)

        login_as user
        user
      end
    end

    module AuthRequestHelper
      #
      # pass the @env along with your request, eg:
      #
      # GET '/labels', {}, @env
      #
      def http_login(username = 'username', password = 'password')
        @env ||= {}
        @env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
      end
    end
  end
end
