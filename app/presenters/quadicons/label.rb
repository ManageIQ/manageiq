module Quadicons
  class Label
    attr_reader :record, :context

    delegate :content_tag, :link_to, :to => :context

    def initialize(record, context)
      @record = record
      @context = context
    end

    def render
      quadicon_label_tag do
        render_label
      end
    end

    def render_label(builder = LinkBuilders::Base)
      if context.render_link?
        link_to(label_content, builder.new(record, context).url)
      else
        label_content
      end
    end

    def label_content
      record.try(:name)
    end

    def quadicon_label_tag(&block)
      # TODO: take options
      options = { :class => "quadicon-label" }
      content_tag(:div, options, &block)
    end
  end
end
