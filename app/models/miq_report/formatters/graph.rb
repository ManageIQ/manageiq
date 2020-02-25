module MiqReport::Formatters::Graph
  extend ActiveSupport::Concern

  module ClassMethods
    # Set the graph options based on chart width and height
    def graph_options(options = nil)
      options ||= {}
      options
    end
  end

  def to_chart(theme = nil, show_title = false, graph_options = nil)
    ManageIQ::Reporting::Formatter::ReportRenderer.render(ManageIQ::Reporting::Charting.format) do |e|
      e.options.mri           = self
      e.options.show_title    = show_title
      e.options.graph_options = graph_options unless graph_options.nil?
      e.options.theme         = theme
    end
  end
end
