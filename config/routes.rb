Vmdb::Application.routes.draw do
  if Rails.env.development? && defined?(Rails::Server)
    logger = Logger.new(STDOUT)
    logger.level = Logger.const_get(::Settings.log.level_remote_console.upcase)
    mount RemoteConsole::RackServer.new(:logger => logger) => '/ws/console'
  end
end
