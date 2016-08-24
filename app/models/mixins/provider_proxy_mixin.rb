module ProviderProxyMixin
  extend ActiveSupport::Concern

  def http_proxy_uri
    proxy = VMDB::Util.http_proxy_uri("#{emstype}".to_sym)

    unless proxy
      proxy = VMDB::Util.http_proxy_uri
    end

    proxy
  end
end
