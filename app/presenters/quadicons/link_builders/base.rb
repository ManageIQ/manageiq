module Quadicons
  module LinkBuilders
    class Base
      attr_reader :record, :context

      delegate :url_for_record, :url_for, :to => :context

      def initialize(record, context)
        @record = record
        @context = context
      end

      def link_to(content = nil, given_html_options = {}, &block)
        if block_given?
          given_html_options = content
          context.link_to(url, html_options(given_html_options), &block)
        else
          context.link_to(content, url, html_options(given_html_options))
        end
      end

      def url
        url_for_record(record)
      end

      # Build attributes for anchor tag. Overriden in subclasses.
      def html_options(given_options = {})
        given_options
      end
    end
  end
end
