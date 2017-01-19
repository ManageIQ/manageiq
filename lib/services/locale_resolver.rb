class LocaleResolver
  def self.resolve(headers = {})
    new(headers).resolve
  end

  attr_reader :headers

  def initialize(headers = {})
    @headers = headers
  end

  def resolve
    if user_locale == 'default' || user_locale.nil?
      if server_locale == "default" || server_locale.nil?
        headers['Accept-Language']
      else
        server_locale
      end
    else
      user_locale
    end
  end

  private

  def user_locale
    @user_locale ||= (User.current_user.try(:settings) || {}).fetch_path(:display, :locale)
  end

  def server_locale
    @server_locale ||= ::Settings.server.locale
  end
end
