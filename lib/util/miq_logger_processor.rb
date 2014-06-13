class MiqLoggerProcessor
  include Enumerable

  attr_accessor :file_name

  def initialize(file_name)
    @file_name = file_name
  end

  def each
    File.open(file_name, "r") do |f|
      while (line = get_next_line(f))
        yield line
      end
    end
  ensure
    cleanup_get_next_line
  end

  #
  # Convert the provided data into a graph in png format.  Valid options are:
  #
  # :graph_type:: :line or :stacked
  # :outfile::    output file name (default is "graph.png")
  #
  # :title_font_size::  size of the title in pixels (default is 24)
  # :legend_font_size:: size of the legend items in pixels (default is 12)
  # :marker_font_size:: size of the x axis labels in pixels (default is 10)
  #
  # :x_axis_label:: x axis label (default is header of first column in data)
  # :y_axis_label:: y axis label (default is nil)
  # :title:: Title of the graph (default is "y_axis_label by x_axis_label"; if
  #   y_axis_label is nil, defaults to "series 1, series 2, ...")
  #
  # :y_axis_increment:: y axis increment
  # :minimum_value::    y axis minimum value
  # :maximum_value::    y axis maximum value
  #
  # :convert_data_method:: method to call on each data point if a conversion is
  #   needed (e.g. :to_i)
  #
  def self.to_png(data, options = {})
    require 'gruff'

    graph = case options[:graph_type]
    when :line    then Gruff::Line.new
    when :stacked then Gruff::StackedBar.new
    else               Gruff::Line.new
    end

    graph.title_font_size  = options[:title_font_size]  || 24
    graph.legend_font_size = options[:legend_font_size] || 12
    graph.marker_font_size = options[:marker_font_size] || 10

    header = data[0]
    data = data.transpose
    x_axis_values = data.shift
    x_axis_values.shift

    # TODO: Move this outside of the to_png method to the method that collects the data (like the csv_to_png method)
    convert_data_method = options[:convert_data_method]
    data.each do |datum|
      label = datum.shift
      datum.collect! { |d| d.send(convert_data_method) } if convert_data_method
      graph.data(label, datum)
    end

    graph.x_axis_label = options[:x_axis_label] || header[0]
    graph.y_axis_label = options[:y_axis_label]
    graph.title = options[:title] || "#{graph.y_axis_label || header[1..-1].join(", ")} by #{graph.x_axis_label}"

    graph.y_axis_increment = options[:y_axis_increment] if options[:y_axis_increment]
    graph.minimum_value = options[:minimum_value] if options[:minimum_value]
    graph.maximum_value = options[:maximum_value] if options[:maximum_value]

    graph.labels = {
      0                        => x_axis_values[0],
      x_axis_values.length - 1 => x_axis_values[-1]
    }
    graph.labels[x_axis_values.length / 2] = x_axis_values[x_axis_values.length / 2] if x_axis_values.length > 2

    graph.write(options[:outfile] || 'graph.png')
  end

  def self.csv_to_png(filename, options = {})
    require 'fastercsv'
    to_png(FasterCSV.read(filename), options)
  end

  private

  def get_next_line(f)
    return nil if @next_line == :eof

    line = @next_line || ""

    loop do
      new_line = f.gets
      if new_line.nil?
        @next_line = :eof
        return MiqLoggerLine.new(line)
      elsif @next_line.nil?
        @next_line = new_line
        line << new_line
      elsif new_line[0, 6] =~ /^\[(?:----|\d{4})\]$/
        @next_line = new_line
        return MiqLoggerLine.new(line)
      else
        line << new_line
      end
    end
  end

  def cleanup_get_next_line
    remove_instance_variable(:@next_line) if instance_variable_defined?(:@next_line)
  end
end

class MiqLoggerLine < String
  def parts
    @parts ||= self.class.split_raw_line(self).freeze
  end
  alias to_a  parts
  alias split parts

  PARTS = %w{time pid tid level q_task_id message}
  PARTS.each_with_index do |m, i|
    define_method(m) { parts[i] }
  end

  def each
    parts.each { |p| yield p }
  end

  private

  def self.split_raw_line(line)
    line = line.to_s
    return if line.empty?

    time = line[11, 26]

    bracket_index = line.index(']', 39)
    pidtid = line[39...bracket_index]
    pid, tid = pidtid.split(':')

    level = line[bracket_index + 2, 5].strip

    message = line[bracket_index + 13..-1]
    if message[0, 9] == "Q-task_id"
      q_bracket_index = message.index(']', 11)
      q_task_id = message[11...q_bracket_index]
      message = message[q_bracket_index + 3..-1]
    else
      q_task_id = nil
    end
    message.chomp!

    return time, pid, tid, level, q_task_id, message
  rescue
    return nil, nil, nil, nil, nil, line
  end
end
