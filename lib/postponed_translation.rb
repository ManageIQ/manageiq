# meant for cases when you need to N_(string-with-format)
# the syntax for new is the same as for String#format

# example:
#
# PostponedTranslation.new( _N("%s Alert Profiles")) { "already translated string" }
# PostponedTranslation.new( _N("%{model} Alert Profiles")) do {:model => ui_lookup(:models => variable)} end

class PostponedTranslation
  def initialize(string, &block)
    @string = string
    @block = block
  end

  # meant to catch cases where PostponedTranslation is not supported
  def to_s
    $log.warn("PostponedTranslation#to_s should not be called - leaving untranslated")
    @string % @block.call
  end

  def translate
    _(@string) % @block.call
  end

  # when we have a generic Proc support - TreeBuilder for example
  def to_proc
    -> { translate }
  end
end
