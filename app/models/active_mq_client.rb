require 'stomp'

class ActiveMqClient < Stomp::Client
  def self.open(long_live = false, client_id = nil)
    # TODO: need to be able to configure host
    hosts = [{:login => "admin", :passcode => "smartvm", :host => "127.0.0.1", :port => 61613}]
    headers = {}
    headers.merge!(:host => "127.0.0.1", :"accept-version" => "1.2", :"heart-beat" => "2000,0") if long_live
    headers.merge!(:"client-id" => client_id) if client_id

    super(:hosts => hosts, :connect_headers => headers)
  end
end
