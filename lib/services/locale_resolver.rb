class LocaleResolver
  def self.resolve(headers = {})
    user_settings = User.current_user.try(:settings)
    user_locale = user_settings[:display][:locale] if user_settings &&
                                                      user_settings.key?(:display) &&
                                                      user_settings[:display].key?(:locale)
    if user_locale == 'default' || user_locale.nil?
      server_locale = ::Settings.server.locale
      locale = if server_locale == "default" || server_locale.nil?
                 headers['Accept-Language']
               else
                 server_locale
               end
    else
      locale = user_locale
    end
    locale
  end
end
