module NumberHelper
  def number_to_human_size(number, *args)
    options = args.extract_options!.reverse_merge(:significant => false, :precision => 1)
    NumberHelper.handling_negatives(number) do |number|
      super(number, options)
    end
  end

  # Converts "1 MB" to "1.megabytes"
  def human_size_to_rails_method(size)
    s = size.dup
    case
    when size.ends_with?(" Byte")
      s[-5..-1] = ""
    when size.ends_with?(" Bytes")
      s[-6..-1] = ""
    when size.ends_with?(" KB")
      s[-3..-1] = ".kilobytes"
    when size.ends_with?(" MB")
      s[-3..-1] = ".megabytes"
    when size.ends_with?(" GB")
      s[-3..-1] = ".gigabytes"
    when size.ends_with?(" TB")
      s[-3..-1] = ".terabytes"
    when size.ends_with?(" PB")
      s[-3..-1] = ".petabytes"
    end
    return s
  rescue
    nil
  end

  # Converts 1048576 (bytes) to "1.megabytes"
  def number_to_rails_method(size)
    return human_size_to_rails_method(number_to_human_size(size, :precision => 1))
  rescue
    nil
  end

  # Converts "1 MB" to 1048576 (bytes)
  def human_size_to_number(size)
    return eval(human_size_to_rails_method(size))
  rescue
    nil
  end

  # Converts "1.megabytes" to "1 MB"
  def rails_method_to_human_size(size)
    return number_to_human_size(eval(size))
  rescue
    nil
  end

  # Converts in a similar manner as number_to_human_size, but in units of MHz
  def mhz_to_human_size(size, *args)
    precision = args.first
    precision = precision[:precision] if precision.kind_of?(Hash)
    precision ||= 1

    NumberHelper.handling_negatives(size) do |size|
      size = size.abs * 1000**2
      ret = case
            when size < 1000**3 then "%.#{precision}f MHz" % (size / (1000**2))
            when size < 1000**4 then "%.#{precision}f GHz" % (size / (1000**3))
            else                     "%.#{precision}f THz" % (size / (1000**4))
            end.sub(".%0#{precision}d" % 0, '')
    end
  rescue
    nil
  end

  private

  def self.handling_negatives(number)
    return nil if number.nil?
    number = Float(number)
    is_negative = number < 0
    ret = yield number.abs
    ret.insert(0, "-") if is_negative
    ret
  end
end
