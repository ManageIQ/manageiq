class LocaleResolver
  def self.resolve(headers = {})
    new(headers).resolve
  end

  attr_reader :headers

  def initialize(headers = {})
    @headers = headers
  end

  def resolve
    if set?(user_locale)
      user_locale
    else
      if set?(server_locale)
        server_locale
      else
        headers['Accept-Language']
      end
    end
  end

  private

  def user_locale
    @user_locale ||= (User.current_user.try(:settings) || {}).fetch_path(:display, :locale)
  end

  def server_locale
    @server_locale ||= ::Settings.server.locale
  end

  def set?(locale)
    locale && locale != "default"
  end
end
