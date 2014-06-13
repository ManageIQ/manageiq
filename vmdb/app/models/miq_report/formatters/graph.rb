module MiqReport::Formatters::Graph
  extend ActiveSupport::Concern

  module ClassMethods
    # Set the graph options based on chart width and height
    def graph_options(w = 350, h = 250, options = nil)
      options ||= {}
      w = w.to_i
      h = h.to_i
      options[:legendwidth]  =  w - 10
      options[:legendheight] = h * 5 / 100
      options[:legendx] = 5
      options[:legendy] = 5

      options[:chartx]     = w * 20 / 100
      options[:chartwidth] = w * 75 / 100

      # Set sizes based on chart pixel width
      if w < 500
        options[:titlesize]  = 16
        options[:legendsize] = 10
        options[:chartsize]  = :small
      elsif w < 700
        options[:titlesize]  = 32
        options[:legendsize] = 12
        options[:chartsize]  = :medium
      else
        options[:titlesize]  = 48
        options[:legendsize] = 15
        options[:chartsize]  = :large
      end

      options[:totalwidth] = w
      if options[:chart2]                           # Does this chart have a composite chart along with it
        if options[:composite]                      # Rendering composite chart
          options[:totalheight] = h * 30 / 100      # Composite area is 30% of total height
          options[:charty]      = (h * 30 / 100) * 28 / 100
          options[:chartheight] = (h * 70 / 100) * 20 / 100
          options[:titlesize]   = options[:titlesize] * 3 / 4
          options[:no_legend]   = true
          options[:no_xlabels]  = nil
        else                                        # Rendering main chart w/composite present
          options[:totalheight] = h * 70 / 100      # Main is 70% of total height
          options[:charty]      = h * 23 / 100
          options[:chartheight] = (h * 70 / 100) * 65 / 100
          options[:no_legend]   = nil
          options[:no_xlabels]  = true
        end
      else                                          # Rendering single chart
        options[:totalheight] = h
        options[:charty]      = h * 23 / 100
        options[:chartheight] = h * 70 / 100
      end

      options[:barchartheight] = h * 50 / 100       # Special bar chart options
      options[:barcharty]      = h * 40 / 100

      options[:piechartx] = w * 12 / 100            # Special pie chart options
      options[:piecharty] = h * 27 / 100

      # Legend font size
      #    options[:legendsize] = w < 500 ? 10 : 20
      options
    end
  end

  def to_chart(theme = nil, show_title = false, graph_options = nil)
    ReportFormatter::ReportRenderer.render(Charting.format) do |e|
      e.options.mri           = self
      e.options.show_title    = show_title
      e.options.graph_options = graph_options unless graph_options.nil?
      e.options.theme         = theme
    end
  end
end
