Vmdb::Application.routes.draw do
  root :to => 'dashboard#login'

  # Let's serve pictures directly from the DB
  get '/pictures/:basename' => 'picture#show', :basename => /[\da-zA-Z]+\.[\da-zA-Z]+/

  # ping response for load balancing
  get '/ping' => 'ping#index'

  if Rails.env.development? && defined?(Rails::Server)
    logger = Logger.new(STDOUT)
    logger.level = Logger.const_get(::Settings.log.level_websocket.upcase)
    mount WebsocketServer.new(:logger => logger) => '/ws'
  end
end
