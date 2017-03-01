# @class MiqIllegalChars
# @brief Common place for illegal character replacement regexes and functions.
# Previously regexes for illegal character replacement were spread throughout
# the code. This class centralized the regexes and replacement functions so
# when these need to change then it can be done in one place.
class MiqIllegalChars

  # Illegal characters: '/', '|'
  @@regex_keep_spaces   = %r{[/|]}
  
  # Illegal characters: '/', '|', ' '
  @@regex_remove_spaces = %r{[/| ]}

  # Replacement character
  @@replacement         = '_'

  # Replace characters in \p str that are not allowed in filenames.
  # Illegal characters are matched from the regexes @@regex_remove_spaces
  # (if \p keep_spaces = false ) @@regex_keep_spaces (if \p keep_spaces = true).
  # Illegal characters are replaced with @@replacement.
  # @param [String] str string to replace
  # @param [Hash] options If options[:keep_spaces] == true, then keep spaces in
  # \p str , otherwise replace spaces. (default = false, replace spaces)
  def self.replace(str, options = {})
    if options.has_key?(:keep_spaces) && options[:keep_spaces] == true
      return str.gsub(@@regex_keep_spaces, @@replacement)
    else
      return str.gsub(@@regex_remove_spaces, @@replacement)
    end
  end
  
end # class MiqIllegalChars
