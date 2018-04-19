#
# The Ruby URI parser doesn't decode the percent encoded characters in the URI, in particular it
# doesn't decode the password which is frequently used when specifying proxy addresses and
# authentication. For example, the following code:
#
#   require 'uri'
#   proxy = URI.parse('http://myuser:%24%3fxxxx@192.168.100.10:3128')
#   puts proxy.password
#
# Produces the following output:
#
#   %24%3fxxxx
#
# But some gems, in particular `rest-client` and `kubeclient`, expect it to decode those characters,
# as they use the value returned by the `password` method directly, and thus they fail to
# authenticate against the proxy server when the password contains percent encoded characters.
#
# To address this issue this file adds a new `proxy` URI schema that almost identical to the `http`
# schema, but that decodes the password before returning it. Users can use this schema instead of
# `http` when they need to use percent encoded characters in the password. For example, the user
# can type in the UI the following proxy URL:
#
#   proxy://myuser:%24%3fxxxx@192.168.100.10:3128
#
# And the new schema will automatically translate `%24%3fxxxx` into `$?xxxx`.
#

require 'cgi'
require 'uri'

module URI
  class PROXY < HTTP
    def password
      value = super
      value = CGI.unescape(value) if value
      value
    end

    def user
      value = super
      value = CGI.unescape(value) if value
      value
    end
  end

  @@schemes['PROXY'] = PROXY
end
