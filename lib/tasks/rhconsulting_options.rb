# @class RhconsultingOptions
# @brief Simple class to parse options passed in to a rake task.
class RhconsultingOptions

  # Tries to parse a string into a more meaningful object using
  # trial and error. The parsing priorities are:
  #  - Integer
  #  - Float
  #  - Boolean
  #
  # If all of those fail, then the original string is returned.
  # @param [String] str the string to try and parse
  # @return A parsed object if we were able to parse something more meaningful,
  # or \p str if we weren't.
  def self.try_parse(str)
    # try parse into an Integer (exception is raised if this fails)
    begin
      return Integer(str)
    rescue
    end

    # try parse into a float (exception is raised if this fails)
    begin
      return Float(str)
    rescue
    end

    # try parse into a boolean (case insensitive)
    if str =~ /^true$/i
      return true
    elsif str =~ /^false$/i
      return false
    end

    # otherwise it's a string
    return str
  end

  # Parses the options in \p options_str and stores them in a hash.
  # The options within \p options_str are assumed to be option and value
  # pairs. The option and value are separated by a '='
  #   Example: "ride_skateboard=true"
  #
  # Each option/value pair is separated by a ';' from the next.
  #  Example: "ride_skateboard=true;shoe_size=11;hat_color=red"
  #
  # When the option/value pairs are parsed each option string is converted
  # into a symbol and used as the key in the options hash that is returned.
  # The value in the pair is parsed using the try_parse() function.
  #
  # @param [String] options_str String of options.
  # @return Hash containing option/value pairs where options are converted
  # to symbols and used as the keys for the hash. Values are parsed using
  # try_parse() and assigned to the corresponding option key in the hash.
  def self.parse_options_str(options_str)
    options = {}
    
    # parse options that are separated by ;
    options_str.split(';').each do |passed_option|
      # break apart the option and the value using = as delimiter
      option, value = passed_option.split('=')
      
      # convert option to symbol and try to parse value into a
      # meaningful data type, otherwise just the value string is returned
      options[option.to_sym] = try_parse(value)
    end
    return options
  end

  # Parses an array of options strings into a single Hash.
  # This simply calls parse_options() for each element in \p options_array
  # and merges all hashes into one.
  # @param [Array<String>] options_array Array of strings, each string
  # containing options.
  # @return A single hash containing all options parsed from the option
  # strings in \p options_array
  def self.parse_options_array(options_array)
    options = {}
    options_array.flatten.each do |options_str|
      parsed_options = parse_options(options_str)
      options.merge!(parsed_options)
    end
    return options
  end

  # Parses the options into a hash.
  # @param [mixed] options 
  def self.parse_options(options)
    # If the option strings are in an array, use the array parsing
    # method
    case options
    when Array
      return parse_options_array(options)
    end
    
    # otherwise assume string
    return parse_options_str(options)
  end
  
end # class RhconsultingOptions
