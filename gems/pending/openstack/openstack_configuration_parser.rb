class OpenstackConfigurationParser
  def self.parse(file_content)
    new.parse(file_content)
  end

  def parse(file_content)
    parse_file_attributes(file_content)
  end

  private

  # Section in a format e.g. [DEFAULT]
  SECTION_REGEXP                       = /^\s*\[(.+?)\]\s*/
  # Its attribute e.g. rpc_thread_pool_size=64, or starting with a #, which is just comment marking a default
  # value. Limited to snake_case words for attribute names and = as delimiter.
  ATTRIBUTE_REGEXP                     = /^\s*([\w]+)\s*[=]\s*(.*?)\s*$/
  COMMENTED_ATTRIBUTE_REGEXP           = /^\s*[#\;]+([\w]+)\s*[=]\s*(.*?)\s*$/
  # Anything starting with #
  COMMENTED_LINE_REGEXP                = /^\s*[#\;]+\s*(.*?)$/
  # Description is the same as commented line, but it is expected, that immediately after block of description, there
  # needs to be an attribute. Then it's description of attribute, otherwise it's thrown away as comment.
  DESCRIPTION_REGEXP                   = COMMENTED_LINE_REGEXP
  # Continuation line is anything starting with space, only condition is that there needs to be attribute above the
  # block of the continuation lines and the block of the continuation lines needs to be indented more than the
  # attribute.
  CONTINUATION_LINE_REGEXP             = /^\s+(.+?)\s*$/
  # Header is any line contaning ====, other headers like in nova are separated by blank line and are ignored too.
  HEADER_REGEXP                        = /^.*?====.*?$/
  # Interpolation in format %(attribute_name)
  BASIC_INTERPOLATION_REGEXP           = /\%\((.+?)\)/
  # Interpolation in format $attribute_name
  BASIC_OPENSTACK_INTERPOLATION_REGEXP = /\$([\w_]+)/
  # Interpolation in format ${attribute_name}
  EXTENDED_INTERPOLATION_REGEXP        = /\$\{(.+?)\}/

  def parse_file_attributes(file)
    # Functionality of python's ConfigParser, extended with parsing of the descriptions, specific to OpenStack config
    # files and specific OpenStack interpolation. Also only '=' is allowed as key/value delimiter and keys has to be
    # in snake case strictly matched by \w. As it is strict format used by openstack config files.
    attributes_hash = {}
    attribute       = {}
    section         = nil

    last_attribute             = {}
    last_attribute_line_indent = 0
    file.each_line do |line|
      line_indent = count_leading_spaces(line)

      if (match = line.match(CONTINUATION_LINE_REGEXP)) && last_attribute[:name] &&
         line_indent > last_attribute_line_indent
        # If value is set and line start with spaces, and indentation is bigger than indentation of attribute it's a
        # continued value
        next if line.match(COMMENTED_LINE_REGEXP) # ignore continuation lines that are comments

        existing_attribute = attributes_hash.fetch_path(section, last_attribute[:name])

        if existing_attribute && match[1]
          existing_attribute[:value] += "\n" + match[1]
          existing_attribute[:value_interpolated] += "\n" + match[1]
        end

        next
      else
        last_attribute = {}
      end

      if (match = line.match(SECTION_REGEXP))
        # Section in a format e.g. [DEFAULT], we save it without braces, section applies until new one is defined
        section = match[1]
      elsif (match = (line.match(ATTRIBUTE_REGEXP) || line.match(COMMENTED_ATTRIBUTE_REGEXP)))
        # Its attribute e.g. rpc_thread_pool_size=64, or starting with a #, which is just comment marking a default
        # value.
        # Look if we already have the attribute, cause it can be redefined multiple times, last occurrence counts and
        # non commented value has always precedence over commented. Name and Section are an unique identifier inside
        # of the file.
        attribute[:name]               = match[1]
        attribute[:value]              = match[2]
        attribute[:value_interpolated] = match[2].dup
        attribute[:section]            = section
        # Allowed values of source are ['defined', 'default'], defined says the value was actually defined in conf
        # file, default says it is present only as a comment, that shows what should be the default value, if it's not
        # redefined. It is based on commented_line boolean
        attribute[:source]             = nil
        commented_line                 = line.match(COMMENTED_LINE_REGEXP)

        if (existing_attribute = attributes_hash.fetch_path(section, attribute[:name]))
          # If it's commented attribute, we will not change value of existing attribute
          unless commented_line
            existing_attribute[:value]              = attribute[:value]
            existing_attribute[:value_interpolated] = attribute[:value_interpolated]
            existing_attribute[:source] = 'defined'
          end
        else
          # New attribute, just add it whole
          attribute[:source] = commented_line ? 'default' : 'defined'
          (attributes_hash[section] ||= {})[attribute[:name]] = attribute
        end

        unless commented_line
          # Placeholder for continuation line, only not commented lines can have continuation lines
          last_attribute_line_indent = count_leading_spaces(line)
          last_attribute = attribute
        end
        # Start over after creating each attribute
        attribute = {}
      elsif (match = line.match(DESCRIPTION_REGEXP))
        # If line starts with comment and it's not attribute, it's description of the attribute
        next if line.match(HEADER_REGEXP) # don't put headers into description
        attribute[:description] ||= ""
        attribute[:description] += "\n" unless attribute[:description].blank?
        attribute[:description] += match[1]
      else
        # New line or unknown, reset attribute and start over
        last_attribute = {}
        attribute      = {}
      end
    end

    make_interpolation!(attributes_hash)

    # Convert nested hashes to flat list of attributes
    attributes_hash.values.each_with_object([]) { |x, obj| obj.concat(x.values) }
  end

  def make_interpolation!(attributes_hash)
    # As specified in python doc, there is special section named 'DEFAULT', that has default values for all sections
    default_section_hash = attributes_hash['DEFAULT'] || {}

    # Functionality of python's class configparser.BasicInterpolation
    attributes_hash.values.each do |section_hash|
      section_hash.values.each do |attribute|
        next if attribute[:value_interpolated].blank?
        interpolated = true
        max_depth    = 100
        depth        = 0
        while interpolated && (depth < max_depth)
          # Each interpolation can interpolate string containing another interpolation, so we need to cycle until the
          # string is fully interpolated. With max depth 100, in case there are some funky cycle references.
          interpolated   = false
          interpolated ||= basic_interpolation!(attribute[:value_interpolated], default_section_hash, section_hash)
          interpolated ||= basic_interpolation_openstack!(attribute[:value_interpolated], default_section_hash,
                                                          section_hash)
          interpolated ||= extended_interpolation!(attribute[:value_interpolated], default_section_hash, section_hash,
                                                   attributes_hash)
          depth += 1
        end
      end
    end
  end

  def basic_interpolation!(value, default_section_hash, section_hash)
    # Functionality of python's class configparser.BasicInterpolation
    # Interpolation in format %(home_dir), looks in current section or default section, if interpolation is not found.
    # Keep the string intact
    interpolated = false
    value.gsub!(BASIC_INTERPOLATION_REGEXP) do |x|
      interpolated = section_hash.fetch_path($1, :value) || default_section_hash.fetch_path($1, :value)
      interpolated || x
    end
    interpolated
  end

  def basic_interpolation_openstack!(value, default_section_hash, section_hash)
    # Interpolation in the form of $host only appears in OpenStack conf files and is not documented in python
    # configparser.
    # Interpolation in format $home_dir, looks in current section or default section,  if interpolation is not found
    # keep the string intact.
    interpolated = false
    value.gsub!(BASIC_OPENSTACK_INTERPOLATION_REGEXP) do |x|
      interpolated = section_hash.fetch_path($1, :value) || default_section_hash.fetch_path($1, :value)
      interpolated || x
    end
    interpolated
  end

  def extended_interpolation!(value, default_section_hash, section_hash, attributes_hash)
    # Functionality of python's class configparser.ExtendedInterpolation.
    interpolated = false
    value.gsub!(EXTENDED_INTERPOLATION_REGEXP) do |x|
      if x.include?(':')
        # Interpolation is in format ${Frameworks:Python}, explicitly saying what section should be used, if
        # interpolation is not found keep the string intact.
        section, name = $1.split(':')
        interpolated = attributes_hash.fetch_path(section, name)
        interpolated || x
      else
        # Interpolation is in format ${Python}, section is not defined use current section or default, if
        # interpolation is not found, keep the string intact.
        interpolated = section_hash.fetch_path($1, :value) || default_section_hash.fetch_path($1, :value)
        interpolated || x
      end
    end
    interpolated
  end

  def count_leading_spaces(line)
    line.index(/[^ ]/) || 0
  end
end
