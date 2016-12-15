class MiqReportFormats
  format_hash = YAML.load_file(ApplicationRecord::FIXTURE_DIR.join('miq_report_formats.yml')).freeze
  FORMATS                = format_hash[:formats].freeze
  DEFAULTS_AND_OVERRIDES = format_hash[:defaults_and_overrides].freeze

  def self.available_formats_for(column, suffix, datatype)
    is_break_sfx = (suffix && MiqReport.is_break_suffix?(suffix))
    FORMATS.each_with_object({}) do |(format_name, properties), result|
      # Ignore formats that don't include suffix if the column name has a break suffix
      next if is_break_sfx && (properties[:suffixes].nil? || !properties[:suffixes].include?(suffix.to_sym))
      next unless (properties[:columns] && properties[:columns].include?(column)) ||
                  (properties[:sub_types] && properties[:sub_types].include?(sub_type(column))) ||
                  (properties[:data_types] && properties[:data_types].include?(datatype)) ||
                  (properties[:suffixes] && properties[:suffixes].include?(suffix.to_sym))
      result[format_name] = properties[:description]
    end
  end

  def self.default_format_for(column, suffix, datatype)
    DEFAULTS_AND_OVERRIDES[:formats_by_suffix][suffix] ||
      DEFAULTS_AND_OVERRIDES[:formats_by_column][column] ||
      DEFAULTS_AND_OVERRIDES[:formats_by_sub_type][MiqReportFormats.sub_type(column)] ||
      DEFAULTS_AND_OVERRIDES[:formats_by_data_type][datatype]
  end

  def self.sub_type(column)
    DEFAULTS_AND_OVERRIDES[:sub_types_by_column][column]
  end
end
