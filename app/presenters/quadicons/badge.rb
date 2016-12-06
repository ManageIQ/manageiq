module Quadicons
  class Badge
    attr_reader :record, :context

    delegate :content_tag, :image_tag, :to => :context

    def initialize(record, context)
      @record = record
      @context = context
    end

    def render
      badge_tag do
        image_tag("100/shield.png")
      end
    end

    def badge_tag(&block)
      content_tag(:div, :class => "quadicon-badge", &block)
    end
  end
end
