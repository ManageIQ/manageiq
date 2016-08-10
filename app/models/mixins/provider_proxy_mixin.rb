module ProviderProxyMixin
  extend ActiveSupport::Concern

  def http_proxy_uri
    proxy = VMDB::Util.http_proxy_uri("#{emstype}_http_proxy".to_sym)

    unless proxy
      proxy = VMDB::Util.http_proxy_uri
    end

    proxy
  end
end
