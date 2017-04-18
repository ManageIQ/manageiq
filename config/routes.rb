Vmdb::Application.routes.draw do
  root :to => 'dashboard#login'

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
        :get     => "show",
        :post    => "update",
        :put     => "update",
        :patch   => "update",
        :delete  => "destroy",
        :options => "options"
      }.freeze
    end

    Api::ApiConfig.collections.each do |collection_name, collection|
      scope collection_name, :controller => collection_name do
        # OPTIONS action for each collection
        if collection.options.include?(:arbitrary_resource_path)
          match "/(*c_suffix)", :controller => collection_name, :action => :options, :via => :options
        else
          match "/(:c_id)", :controller => collection_name, :action => :options, :via => :options
        end

        collection.verbs.each do |verb|
          root :action => API_ACTIONS[verb], :via => verb if collection.options.include?(:primary)

          next unless collection.options.include?(:collection)

          if collection.options.include?(:arbitrary_resource_path)
            case verb
            when :get
              root :action => :index
              get "/*c_suffix", :action => :show
            else
              match "(/*c_suffix)", :action => API_ACTIONS[verb], :via => verb
            end
          else
            case verb
            when :get
              root :action => :index
              get "/:c_id", :action => :show
            else
              match "(/:c_id)", :action => API_ACTIONS[verb], :via => verb
            end
          end
        end

        Array(collection.subcollections).each do |subcollection_name|
          match "/:c_id/#{subcollection_name}(/:s_id)", :controller => collection_name, :action => :options, :via => :options

          Api::ApiConfig.collections[subcollection_name].verbs.each do |verb|
            case verb
            when :get
              get "/:c_id/#{subcollection_name}", :action => :index
              get "/:c_id/#{subcollection_name}/:s_id", :action => :show
            else
              match("/:c_id/#{subcollection_name}(/:s_id)", :action => API_ACTIONS[verb], :via => verb)
            end
          end
        end
      end
    end
  end

  # ping response for load balancing
  get '/ping' => 'ping#index'

  match "/auth/:provider/callback" => "sessions#create", :via => :get

  if Rails.env.development? && defined?(Rails::Server)
    logger = Logger.new(STDOUT)
    logger.level = Logger.const_get(::Settings.log.level_websocket.upcase)
    mount WebsocketServer.new(:logger => logger) => '/ws'
  end
end
