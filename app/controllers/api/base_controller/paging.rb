module Api
  class BaseController
    class Paging

      attr_reader :offset, :limit

      def initialize(params)
        @offset = params["offset"]
        @limit = params["limit"]
      end

      def paginate?
        offset || limit
      end

      def options(options)
        return options unless paginate?
        options.merge!(paging_hash)
      end

      private

      def paging_hash
        {
          :offset => offset,
          :limit => limit
        }
      end
    end
  end
end
