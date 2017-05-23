module Api
  class LinkBuilder
    PAGING_LINKS = [
      :self,
      :next,
      :previous,
      :first,
      :last
    ].freeze

    attr_reader :offset, :limit, :href, :count, :subcount, :subquery_count

    def initialize(params, href, counts)
      @offset = params["offset"].to_i if params["offset"]
      @limit = params["limit"].to_i if params["limit"]
      @href = href
      return unless counts
      @count = counts[:count]
      @subcount = counts[:subcount]
      @subquery_count = counts[:subquery_count]
    end

    def links
      PAGING_LINKS.each_with_object({}) do |link, object|
        new_href = send(link)
        next unless new_href
        object[link] = new_href
      end
    end

    def pages
      (paging_count / limit.to_f).ceil
    end

    def links?
      offset && limit
    end

    private

    def self_href
      @self_href ||= format_href(offset)
    end

    def format_href(new_offset)
      href.sub "offset=#{offset}", "offset=#{new_offset}"
    end

    def paging_count
      @paging_count ||= subquery_count.nil? ? count : subquery_count
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
