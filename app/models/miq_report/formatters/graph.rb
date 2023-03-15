module MiqReport::Formatters::Graph
  extend ActiveSupport::Concern

  module ClassMethods
    # Set the graph options based on chart width and height
    def graph_options(options = nil)
      options ||= {}
      options
    end
  end

  # Sets the boundary of staying with smaller unit versus going up.
  # Example: with the value, say, 10, if the data is 9000 MB, we'd stay with MB, while we'd go to GB if it's 11000 MB.
  UNIT_THRESHOLD = 10

  def to_chart(theme = nil, show_title = false, graph_options = nil)
    ManageIQ::Reporting::Formatter::ReportRenderer.render(ManageIQ::Reporting::Charting.format) do |e|
      if col_formats
        # NOTE: This code intentionally does not use number_to_human_size to create a human-readable
        #   chart summary, because we want to match the unit of the column, regardless of the size.
        #   This code chooses the unit first, then converts the size to that unit, as opposed to
        #   number_to_human_size which chooses the most optimal unit for the size.
        col_formats.each_with_index do |format, i|
          next unless [:bytes_human_precision_2, :kilobytes_human, :megabytes_human, :megabytes_human_precision_2, :gigabytes_human, :gigabytes_human_precision_2].include?(format)

          final_unit = 1
          table.data.each do |d|
            unit = [1.terabytes, 1.gigabytes, 1.megabytes, 1.kilobytes].detect { |u| d[i] / u >= UNIT_THRESHOLD }
            final_unit = unit if unit > final_unit
          end
          table.data.each do |d|
            d[i] /= final_unit
          end
        end
      end
      e.options.mri           = self
      e.options.show_title    = show_title
      e.options.graph_options = graph_options unless graph_options.nil?
      e.options.theme         = theme
    end
  end
end
