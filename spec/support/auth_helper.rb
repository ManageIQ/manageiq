module Spec
  module Support
    module AuthHelper
      def http_login(username = 'username', password = 'password')
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
      end

      def login_as(user, stub_controller: false)
        User.current_user = user
        STDERR.puts "WARNING: double stubbing user - only use login_as or stub_user once" if user != User.current_user
        session[:userid]  = user.userid
        session[:group]   = user.current_group_id
        allow(controller).to receive(:current_user).and_return(user) if stub_controller
        user
      end

      # Stubs the user in context for a controller
      # @param features (:all|:none|Array<>,String,Symbol) features for a user
      #    :all   means all features are avaiable, essentially "super_administrator"
      #    :none  means no features are available. (feature "none" ends up being assigned - which does nothing)
      def stub_user(features:)
        allow(User).to receive(:server_timezone).and_return("UTC")
        allow_any_instance_of(described_class).to receive(:set_user_time_zone)

        features = "everything" if features == :all
        login_as FactoryBot.create(:user, :features => Array.wrap(features).map(&:to_s)), :stub_controller => true
      end

      def stub_admin
        stub_user(:features => :all)
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
