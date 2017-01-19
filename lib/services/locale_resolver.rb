class LocaleResolver
  def self.resolve(headers = {})
    new(headers).resolve
  end

  attr_reader :headers

  def initialize(headers = {})
    @headers = headers
  end

  def resolve
    if !set?(user_locale)
      if !set?(server_locale)
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

  def set?(locale)
    locale && locale != "default"
  end
end
