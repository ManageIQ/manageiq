# frozen_string_literal: true

module SpecSupport
  module TableTranslationHelper
    def extract_table_entries(file_path)
      yaml = YAML.load_file(file_path)
      yaml['tables'].keys
    rescue Psych::SyntaxError => e
      raise "Invalid YAML in #{file_path}: #{e.message}"
    rescue Errno::ENOENT => e
      raise "File not found: #{file_path}"
    end
  end
end