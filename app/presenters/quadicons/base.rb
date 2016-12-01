module Quadicons
  class Base
    attr_reader :record, :context, :options
    attr_writer :quadrants

    delegate :concat, :content_tag, :link_to, :to => :context

    def initialize(record, context)
      @record  = record
      @context = context
    end

    def render_quadrants
      quadrant_classes.compact.map do |quadrant|
        concat(quadrant.render)
      end
    end

    def render_single_quadrant
      quadrant_classes.first && concat(quadrant_classes.first.render)
    end

    # Do nothing in base
    def render_badge
    end

    def render_label
      concat(Quadicons::Label.new(record, context).render)
    end

    def render
      if render_single?
        render_single
      else
        render_full
      end
    end

    def quadicon_tag(options = {}, &block)
      options = default_tag_options.merge!(options)
      content_tag(:div, options, &block)
    end

    def quadicon_button_tag(options = {}, &block)
      options = { :class => "quadrant-group" }.merge!(options)

      if context.render_link?
        options.reverse_merge!(url_options)

        url = url_builder.new(record, context).url
        concat(link_to(url, options, &block))
      else
        content_tag(:div, options, &block)
      end
    end

    def quadrants
      @quadrants ||= quadrant_list
    end

    def quadrant_classes
      quadrants.map do |type|
        Quadrants.quadrantize(type, record, context)
      end
    end

    def quadrant_list
      if render_full?
        []
      else
        [:type_icon]
      end
    end

    def render_link?
      context.render_link?
    end

    def render_full?
      !render_single?
    end

    def render_single?
      false
    end

    def render_full
      quadicon_tag do
        quadicon_button_tag do
          render_quadrants
          render_badge
        end

        render_label
      end
    end

    def render_single
      quadicon_tag do
        render_single_quadrant
        render_label
      end
    end

    def url_options
      {}
    end

    private

    def default_tag_classes
      css = ["quadicon", css_class]

      if render_single?
        css << "quadicon-single"
      end

      css
    end

    def default_tag_options
      {
        :class => default_tag_classes.join(' '),
        :id    => "quadicon_#{record.id}",
        :title => default_title_attr
      }
    end

    def default_title_attr
      "#{record_class}_#{record.id}"
    end

    def css_class
      self.class.to_s.demodulize.underscore
    end

    def record_class
      record.class.to_s.demodulize.underscore
    end

    def url_builder
      UrlBuilder
    end
  end
end
