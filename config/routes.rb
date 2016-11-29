Vmdb::Application.routes.draw do
  root :to => 'dashboard#login'
  get '/saml_login(/*path)' => 'dashboard#saml_login'

  # Let's serve pictures directly from the DB
  get '/pictures/:basename' => 'picture#show', :basename => /[\da-zA-Z]+\.[\da-zA-Z]+/

  # Enablement for the REST API

  # Semantic Versioning Regex for API, i.e. vMajor.minor.patch[-pre]
  API_VERSION_REGEX = /v[\d]+(\.[\da-zA-Z]+)*(\-[\da-zA-Z]+)?/ unless defined?(API_VERSION_REGEX)

  namespace :api, :path => "api(/:version)", :version => API_VERSION_REGEX, :defaults => {:format => "json"} do
    root :to => "api#index"
    match "/", :to => "api#options", :via => :options

    unless defined?(API_ACTIONS)
      API_ACTIONS = {
        :get    => "show",
        :post   => "update",
        :put    => "update",
        :patch  => "update",
        :delete => "destroy",
        :options => "options"
      }.freeze
    end

    Api::ApiConfig.collections.each do |collection_name, collection|
      # OPTIONS action for each collection
      match collection_name.to_s, :controller => collection_name, :action => :options, :via => :options

      scope collection_name, :controller => collection_name do
        collection.verbs.each do |verb|
          root :action => API_ACTIONS[verb], :via => verb if collection.options.include?(:primary)

          next unless collection.options.include?(:collection)

          if collection.options.include?(:arbitrary_resource_path)
            match "(/*c_suffix)", :action => API_ACTIONS[verb], :via => verb
          else
            match "(/:c_id)", :action => API_ACTIONS[verb], :via => verb
          end
        end

        Array(collection.subcollections).each do |subcollection_name|
          Api::ApiConfig.collections[subcollection_name].verbs.each do |verb|
            match("/:c_id/#{subcollection_name}(/:s_id)", :action => API_ACTIONS[verb], :via => verb)
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
      get controller_name, :controller => controller_name, :action => :index
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

  # pure-angular templates
  get '/static/*id' => 'static#show', :format => false

  # ping response for load balancing
  get '/ping' => 'ping#index'

  resources :ems_cloud, :as => :ems_clouds
  resources :ems_infra, :as => :ems_infras
  resources :ems_container, :as => :ems_containers
  resources :ems_middleware, :as => :ems_middlewares
  resources :ems_datawarehouse, :as => :ems_datawarehouses
  resources :ems_network, :as => :ems_networks

  match "/auth/:provider/callback" => "sessions#create", :via => :get

  if Rails.env.development? && defined?(Rails::Server)
    mount WebsocketServer.new(:logger => Logger.new(STDOUT)) => '/ws'
  end
end
