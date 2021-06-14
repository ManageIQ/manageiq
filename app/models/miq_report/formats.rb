class MiqReport::Formats
  private_class_method def self.format_hash
    @format_hash ||= YAML.load_file(ApplicationRecord::FIXTURE_DIR.join('miq_report_formats.yml')).freeze
  end

  private_class_method def self.formats
    format_hash[:formats]
  end

  private_class_method def self.defaults_and_overrides
    format_hash[:defaults_and_overrides]
  end

  def self.available_formats_for(column, suffix, datatype)
    is_break_sfx = (suffix && MiqReport.is_break_suffix?(suffix))
    formats.each_with_object({}) do |(format_name, properties), result|
      # Ignore formats that don't include suffix if the column name has a break suffix
      next if is_break_sfx && (properties[:suffixes].nil? || !properties[:suffixes].include?(suffix.to_sym))
      next unless (properties[:columns] && properties[:columns].include?(column)) ||
                  (properties[:sub_types] && properties[:sub_types].include?(sub_type(column))) ||
                  (properties[:data_types] && properties[:data_types].include?(datatype)) ||
                  (properties[:suffixes] && properties[:suffixes].include?(suffix.to_sym)) ||
                  format_name == sub_type(column) ||
                  format_name == defaults_and_overrides[:formats_by_sub_type][sub_type(column)]

      result[format_name] = properties[:description]
    end
  end

  def self.default_format_for_path(path, datatype)
    column = path.split('-').last.to_sym
    suffix = column.to_s.split('__').last.try(:to_sym)
    # HACK: formats for columns are unqualified, so we need a
    # temporary way to avoid collisions
    defaults_and_overrides[:formats_by_path].fetch(path.to_sym) do
      defaults_and_overrides[:formats_by_suffix][suffix] ||
        defaults_and_overrides[:formats_by_column][column] ||
        defaults_and_overrides[:formats_by_sub_type][sub_type(column)] ||
        defaults_and_overrides[:formats_by_data_type][datatype]
    end
  end

  def self.default_format_details_for(path, column, datatype)
    format = formats[default_format_for_path(path, datatype)]
    if format
      format = format.deep_clone # Make sure we don't taint the original
      if defaults_and_overrides[:precision_by_column].key?(column.to_sym)
        format[:precision] = defaults_and_overrides[:precision_by_column][column.to_sym]
      end
    end
    format
  end

  def self.details(format_name)
    formats[format_name.try(:to_sym)]
  end

  def self.sub_type(column)
    defaults_and_overrides[:sub_types_by_column][column]
  end
end
