Vmdb::Application.routes.draw do
  if Rails.env.development? && defined?(Rails::Server)
    logger = Logger.new(STDOUT)
    logger.level = Logger.const_get(::Settings.log.level_websocket.upcase)
    mount WebsocketServer.new(:logger => logger) => '/ws'
  end

  if Rails.env.development?
    mount GraphiQL::Rails::Engine, :at => "/graphql/explorer", :graphql_path => "/graphql"
  end
end
