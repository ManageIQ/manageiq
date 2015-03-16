require 'uri'

# HACK URI::Generic.build to allow a IPv6 host value.
#
# It's a temporary workaround until https://github.com/ruby/ruby/pull/765 is
# readily available.  As of this writing, ruby 2.0.0p643 and ruby 2.2.0 have this fixed.
# Ruby 2.1.5, and ruby 2.0.0p598 and lower don't have this fixed and NEED this hack.
# Ruby 2.0: https://bugs.ruby-lang.org/issues/10873 (backported and in p643)
# Ruby 2.1: https://bugs.ruby-lang.org/issues/10875 (backported and not released yet)
# Ruby 2.2: https://bugs.ruby-lang.org/issues/10874 (backported and in 2.2.0)
#
# Workaround before this hack:
#  # Don't pass :host => "::1" to .build as it throws URI::InvalidComponentError
#  uri = URI::HTTPS.build(:path => "/sdk")
#  uri.hostname = "::1"
#  uri.to_s # => "https://[::1]/sdk"
#
# After this hack the caller doesn't need to know to use [::1] or hostname= method:
#  uri = URI::HTTPS.build(:host => "::1", :path => "/sdk")
#  uri.to_s # => "https://[::1]/sdk"
#
def uri_supports_ipv6_on_build?
  URI::HTTPS.build(:host => "::1", :path => "/sdk")
rescue URI::InvalidComponentError
  false
end

unless uri_supports_ipv6_on_build?
  module MiqURI
    module ClassMethods
      def build(args)
        host, args = _delete_host(args)

        # Call .new without the host
        u = super(args)

        # Use IPv6 friendly hostname=
        u.hostname = host if host
        u
      end

      private
      def _delete_host(args)
        args = args.dup

        # Save off and remove the host arg
        if args.kind_of?(Array)
          # host is the 3rd item in the Array:
          # scheme, userinfo, host, port, registry, path, opaque, query and fragment
          host, args[2] = args[2], nil
        elsif args.kind_of?(Hash)
          host = args.delete(:host)
        end
        return host, args
      end
    end

    def self.prepended(base)
      class << base
        prepend ClassMethods
      end
    end
  end

  module URI
    class Generic
      prepend MiqURI
    end
  end
end
