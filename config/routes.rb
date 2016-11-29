Vmdb::Application.routes.draw do
  root :to => 'dashboard#login'

  get '/saml_login(/*path)' => 'dashboard#saml_login'

  # pure-angular templates
  get '/static/*id' => 'static#show', :format => false

  # ping response for load balancing
  get '/ping' => 'ping#index'

  get "/auth/:provider/callback" => "sessions#create"

  # serve pictures directly from the DB
  get '/pictures/:basename' => 'picture#show', :basename => /[\da-zA-Z]+\.[\da-zA-Z]+/

  #
  # REST API
  #

  api_actions = {
    :get     => "show",
    :post    => "update",
    :put     => "update",
    :patch   => "update",
    :delete  => "destroy",
    :options => "options"
  }

  api_namespace_options = {
    :path        => "api(/:version)",
    :defaults    => {:format  => "json"},
    :constraints => {:version => Api::ApiConfig.version.route_regex}
  }

  namespace :api, api_namespace_options do
    root :to => "api#index"
    match "/", :to => "api#options", :via => :options

    Api::ApiConfig.collections.each do |collection_name, collection|
      match collection_name.to_s, :controller => collection_name, :action => :options, :via => :options

      scope collection_name, :controller => collection_name do
        collection.verbs.each do |verb|
          root :action => api_actions[verb], :via => verb if collection.options.include?(:primary)

          next unless collection.options.include?(:collection)

          if collection.options.include?(:arbitrary_resource_path)
            match "(/*c_suffix)", :action => api_actions[verb], :via => verb
          else
            match "(/:c_id)", :action => api_actions[verb], :via => verb
          end
        end

        Array(collection.subcollections).each do |subcollection_name|
          Api::ApiConfig.collections[subcollection_name].verbs.each do |verb|
            match("/:c_id/#{subcollection_name}(/:s_id)", :action => api_actions[verb], :via => verb)
          end
        end
      end
    end
  end

  #
  # Controllers
  #

  controller_routes = YAML.load_file(Rails.root.join("config/controller_routes.yml"))
  controller_routes.delete("__grouped_routes__") # Delete placeholder entry for grouping
  controller_routes.each do |controller_name, controller_actions|
    # Default route with no action to controller's index action
    unless %w(ems_cloud ems_infra ems_container ems_middleware ems_datawarehouse ems_network).include?(controller_name)
      get(
        "#{controller_name}(/:id)",
        :controller => controller_name,
        :action     => :index,
        :id         => ArRegion::CID_OR_ID_MATCHER_ROUTES,
        :as         => controller_name
      )
    end

    if controller_actions["get"]
      get(
        "#{controller_name}/:action(/:id)",
        :controller => controller_name,
        :action     => Regexp.new(controller_actions["get"].flatten.join("|"))
      )
    end

    if controller_actions["post"]
      post(
        "#{controller_name}/:action(/:id)",
        :controller => controller_name,
        :action     => Regexp.new(controller_actions["post"].flatten.join("|"))
      )
    end
  end

  resources :ems_cloud, :as => :ems_clouds
  resources :ems_infra, :as => :ems_infras
  resources :ems_container, :as => :ems_containers
  resources :ems_middleware, :as => :ems_middlewares
  resources :ems_datawarehouse, :as => :ems_datawarehouses
  resources :ems_network, :as => :ems_networks

  if Rails.env.development? && defined?(Rails::Server)
    mount WebsocketServer.new(:logger => Logger.new(STDOUT)) => '/ws'
  end
end
