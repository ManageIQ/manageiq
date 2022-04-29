module VMDB
  module Util
    def self.http_proxy_uri(proxy_config = :default)
      proxy = ::Settings.http_proxy[proxy_config].to_hash
      proxy = ::Settings.http_proxy.to_hash unless proxy[:host]
      return nil if proxy[:host].blank?

      user     = proxy.delete(:user)
      user &&= CGI.escape(user)
      password = proxy.delete(:password)
      password &&= CGI.escape(password)
      userinfo = "#{user}:#{password}".chomp(":") unless user.blank?

      proxy[:userinfo]   = userinfo
      proxy[:scheme] ||= "http"
      proxy[:port] &&= proxy[:port].to_i

      URI::Generic.build(proxy)
    end
  end
end
