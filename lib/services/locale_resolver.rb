class LocaleResolver
  def self.resolve(user, headers = {})
    new(user, headers).resolve
  end

  attr_reader :user, :headers

  def initialize(user, headers = {})
    @user = user
    @headers = headers
  end

  def resolve
    return user_locale if set?(user_locale)
    return server_locale if set?(server_locale)
    headers["Accept-Language"]
  end

  private

  def user_locale
    @user_locale ||= (user.try(:settings) || {}).fetch_path(:display, :locale)
  end

  def server_locale
    @server_locale ||= ::Settings.server.locale
  end

  def set?(locale)
    locale && locale != "default"
  end
end
