class MiqReportFormats
  format_hash = YAML.load_file(ApplicationRecord::FIXTURE_DIR.join('miq_report_formats.yml')).freeze
  FORMATS                = format_hash[:formats].freeze
  DEFAULTS_AND_OVERRIDES = format_hash[:defaults_and_overrides].freeze
end
