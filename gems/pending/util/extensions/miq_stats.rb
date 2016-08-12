require 'more_core_extensions/core_ext/array'
require 'more_core_extensions/core_ext/numeric'

module MiqStats
  def self.slope(x_array, y_array)
    return [] if x_array.empty? || y_array.empty?
    raise "Arrays are not the same length, unable to calculate slope" unless x_array.length == y_array.length

    n = x_array.length

    sum_x = x_array.sum
    sum_y = y_array.sum

    xy_array = []
    n.times { |i| xy_array.push(x_array[i] * y_array[i]) }

    sum_xy = xy_array.sum

    x2_array = x_array.inject([]) { |a, v| a.push(v.square) }
    y2_array = y_array.inject([]) { |a, v| a.push(v.square) }

    sum_x2 = x2_array.sum
    sum_y2 = y2_array.sum

    m = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x.square)
    return [] if m.nan?
    b = (sum_y - m * sum_x) / n
    r = (n * sum_xy - sum_x * sum_y) / Math.sqrt((n * sum_x2 - sum_x.square) * (n * sum_y2 - sum_y.square)) rescue nil

    [m, b, r]
  end

  def self.solve_for_y(x, m, b)
    # y = mx + b
    (m * x + b)
  end

  def self.solve_for_x(y, m, b)
    # x = (y - b)/m
    ((y - b) / m)
  end
end

if __FILE__ == $0
  fields = []
  $stdin.each do |line|
    data = line.chomp.split("\t")
    data.each_index do |i|
      fields[i] = [] if fields[i].nil?
      fields[i] << data[i].to_f if data[i].size > 0
    end
  end

  fields.each_index do |i|
    next unless fields[i].size > 0
    puts [i,  fields[i].mean, fields[i].stddev] \
      .collect(&:to_s).join("\t")
  end
end
