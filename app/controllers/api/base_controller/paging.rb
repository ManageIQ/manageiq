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

      attr_reader :offset, :limit, :href
      attr_accessor :count, :subcount

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
      end

      def paging_links(json)
        return unless offset && limit
        json.links do |js|
          PAGING_LINKS.each do |link|
            new_href = send(link)
            next unless new_href
            js.set! link, new_href
          end
        end
      end

      private

      def next
        next_offset = offset + limit
        return if next_offset >= count
        href.gsub "offset=#{offset}", "offset=#{next_offset}"
      end

      def previous
        return if offset.zero?
        prev_offset = (offset - limit)
        href.gsub "offset=#{offset}", "offset=#{prev_offset}"
      end

      def self
        href
      end

      def first
        return href if offset.zero?
        href.gsub "offset=#{offset}", "offset=0"
      end

      def last
        return href if limit.zero? || limit.nil?
        return if (offset + limit) >= count
        last_offset = count - (count % limit)
        href.gsub "offset=#{offset}", "offset=#{last_offset}"
      end
    end
  end
end
