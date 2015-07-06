require 'net/http'

# Monkey patch to fix a IPv6 regression in Net::HTTP
# https://bugs.ruby-lang.org/issues/9129  (trunk, 2.2.0+)
# https://bugs.ruby-lang.org/issues/10530 (2.0.0-p643)
# https://bugs.ruby-lang.org/issues/10531 (2.1 not yet released)
# TODO: Delete me when it's reasonable that most rubies have this fix
if RUBY_VERSION.start_with?("2.1") || (RUBY_VERSION == "2.0.0" && RUBY_PATCHLEVEL < 643)
  module Net
    class HTTP < Protocol
      def proxy_uri # :nodoc:
        @proxy_uri ||= URI::HTTP.new(
          "http".freeze, nil, address, port, nil, nil, nil, nil, nil
        ).find_proxy
      end
    end
  end
end
