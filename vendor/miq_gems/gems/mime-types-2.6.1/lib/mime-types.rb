require 'mini_mime'

module MIME
  class Types
    class << self
      def [](type)
        Array.wrap(MiniMime.lookup_by_content_type(type))
      end

      def type_for(filename)
        Array.wrap(MiniMime.lookup_by_filename(filename))
      end
      alias_method :of, :type_for
    end
  end
end
