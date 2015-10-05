# meant for cases when you need to N_(string-with-format)
# the syntax for new is the same as for String#format

# example:
#
# PostponedTranslation.new( _N("%s Alert Profiles"), "already translated string" )
# PostponedTranslation.new( _N("%{foo} Alert Profiles"), { :foo => "already translated string" })

class PostponedTranslation
  def initialize(string, *args)
    @string = string
    @args = args
    @args = args.first if args.length == 1 && args.first.kind_of?(Hash)
  end

  # meant to catch cases where PostponedTranslation is not supported
  def to_s
    $log.warn("PostponedTranslation#to_s should not be called - leaving untranslated")
    @string % @args
  end

  def translate
    _(@string) % @args
  end

  # when we have a generic Proc support - TreeBuilder for example
  def to_proc
    -> { translate }
  end
end
