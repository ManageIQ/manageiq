Vmdb::Application.routes.draw do
  if Rails.env.development? && ENV['MOUNT_REMOTE_CONSOLE_PROXY']
    logger = Logger.new(STDOUT)
    logger.level = Logger.const_get(::Settings.log.level_remote_console.upcase)
    mount RemoteConsole::RackServer.new(:logger => logger) => '/ws/console'
  end
end
