module Api
  class LinksBuilder
    def initialize(params, href, counts)
      @offset = params["offset"].to_i if params["offset"]
      @limit = params["limit"].to_i if params["limit"]
      @href = href
      @counts = counts if counts
    end

    def links
      {
        :self     => self_href,
        :next     => next_href,
        :previous => previous_href,
        :first    => first_href,
        :last     => last_href
      }.compact
    end

    def pages
      (paging_count / limit.to_f).ceil
    end

    def links?
      offset && limit
    end

    private

    attr_reader :offset, :limit, :href, :counts

    def self_href
      @self_href ||= format_href(offset)
    end

    def format_href(new_offset)
      href.sub("offset=#{offset}", "offset=#{new_offset}")
    end

    def paging_count
      @paging_count ||= counts.subquery_count || counts.count
    end

    def next_href
      next_offset = offset + limit
      return if next_offset >= paging_count
      format_href(next_offset)
    end

    def previous_href
      return if offset.zero?
      prev_offset = offset - limit
      return first_href if prev_offset < 0
      format_href(prev_offset)
    end

    def first_href
      format_href(0)
    end

    def last_href
      last_offset = paging_count - (paging_count % limit)
      format_href(last_offset)
    end
  end
end
