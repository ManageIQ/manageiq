module Quadicons
  module Quadrants
    class Base
      attr_reader :record, :context

      delegate :content_tag, :image_tag, :to => :context

      def initialize(record, context)
        @record = record
        @context = context
      end

      def render
        quadrant_tag do
          image_tag(path)
        end
      end

      def path
        "72/base.png"
      end

      def quadrant_tag(&block)
        # TODO: take options
        options = { :class => default_tag_classes.join(" ") }

        content_tag(:div, options, &block)
      end

      private

      def h(str)
        ERB::Util.html_escape(str)
      end

      def default_tag_classes
        ["quadicon-quadrant"] << css_class
      end

      def css_class
        "quadrant-" << self.class.to_s.demodulize.underscore
      end
    end
  end
end
