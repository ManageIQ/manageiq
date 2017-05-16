module Api
  class BaseController
    class Paging
      PAGING_LINKS = [
        :self,
        :next,
        :previous,
        :first,
        :last
      ].freeze

      attr_reader :offset, :limit, :href, :method
      attr_accessor :count, :subcount, :subquery_count

      def initialize(params, href)
        @offset = params["offset"].to_i if params["offset"]
        @limit = params["limit"].to_i if params["limit"]
        @href = href
      end

      def options(options)
        return options unless offset || limit
        options.merge!(:offset => offset, :limit => limit)
      end

      def collection_counts(json)
        json.set! 'count', count
        json.set! 'subcount', subcount
        json.set! 'pages', pages if paging?
      end

      def paging_links(json)
        return unless paging?
        json.links do |js|
          PAGING_LINKS.each do |link|
            new_href = send(link)
            next unless new_href
            js.set! link, new_href
          end
        end
      end

      private

      def paging?
        offset && limit
      end

      def self_href
        @self_href ||= format_href(offset)
      end

      def format_href(new_offset)
        href.sub "offset=#{offset}", "offset=#{new_offset}"
      end

      def paging_count
        @paging_count ||= subquery_count.nil? ? count : subquery_count
      end

      def pages
        (paging_count / limit.to_f).ceil
      end

      def next
        next_offset = offset + limit
        return if next_offset >= paging_count
        format_href(next_offset)
      end

      def previous
        return if offset.zero?
        prev_offset = offset - limit
        return if prev_offset < 0
        format_href(prev_offset)
      end

      def self
        self_href
      end

      def first
        return if offset.zero?
        format_href(0)
      end

      def last
        return if (offset + limit) >= paging_count
        last_offset = paging_count - (paging_count % limit)
        format_href(last_offset)
      end
    end
  end
end
