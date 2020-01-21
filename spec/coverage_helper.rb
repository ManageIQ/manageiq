require 'active_support/core_ext/kernel/reporting'

# Require all ruby files for accurate test coverage reports
Dir.glob(Rails.root.join("{app,lib}/**/*.rb")).sort.each do |file|
  # Ignore executable scripts and erb templates
  next if %w[*/bin/* */lib/generators/**/templates/*].any? do |glob|
    File.fnmatch(glob, file)
  end

  begin
    silence_warnings { require file }
  rescue StandardError, LoadError, MissingSourceFile
  end
end
