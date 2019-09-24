require 'fast_gettext'

# include this module to see translations in the UI
module Vmdb
  module Gettext
    module Debug
      DL = "\u00BB".encode("UTF-8")
      DR = "\u00AB".encode("UTF-8")

      # modified copy of fast_gettext _ method
      def _(key)
        "#{DL}#{FastGettext._(key)}#{DR}"
      end

      # modified copy of fast_gettext n_ method
      def n_(*keys)
        "#{DL}#{FastGettext.n_(*keys)}#{DR}"
      end

      # modified copy of fast_gettext s_ method
      def s_(key, separator = nil)
        "#{DL}#{FastGettext.s_(key, separator)}#{DR}"
      end

      # modified copy of fast_gettext ns_* method
      def ns_(*keys)
        "#{DL}#{FastGettext.ns_(*keys)}#{DR}"
      end
    end
  end
end
