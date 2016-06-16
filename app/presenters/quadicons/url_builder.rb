module Quadicons
  class UrlBuilder
    attr_reader :record, :context

    delegate :url_for_record, :to => :context

    def initialize(record, context)
      @record = record
      @context = context
    end

    def url
      url_for_record(*url_args)
    end

    def url_args
      [record]
    end
  end
end
