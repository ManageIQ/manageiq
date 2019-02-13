# Add to config/application.rb:
#
#     config.middleware.use 'RequestLogSessionMiddleware'
#
class RequestLogSessionMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    session_id = cookies(env)['_vmdb_session']
    Rails.logger.info("Session ID: #{session_id.inspect}")

    @app.call(env)
  end

  private

  def cookies(env)
    env["HTTP_COOKIE"].split(/\s*;\s*/).map do |keyval|
      keyval.split('=')
    end.to_h
  rescue StandardError
    {}
  end
end
