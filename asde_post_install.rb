require 'uri'
require 'net/http'
require 'json'

# VARS
USER='autosde'
PASSWORD = 'change_me'
DOMAIN = '129.39.244.129'
DIALOG_NAME='AutoSDE Dialog'
CATALOG_NAME='AutoSDE Catalog'
ITEM_NAME='AutoSDE Item'



# POST
uri = URI("https://#{DOMAIN}/api/service_dialogs")
request = Net::HTTP::Post.new(uri)
request.basic_auth(USER, PASSWORD)

catalog_json = JSON.parse('{"action" : "create", "resource" : { "name" :"<NAME>","description" : ""}}')
catalog_json['resource']['name']=CATALOG_NAME
request.set_form_data(catalog_json)

response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
  http.request(request)
end
p response