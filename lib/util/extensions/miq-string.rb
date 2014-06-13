$:.push("#{File.dirname(__FILE__)}/..")
require 'miq-encode'

require 'active_support/inflector'
require 'more_core_extensions/core_ext/string'

class String
  alias original_less_than_less_than <<
  alias original_concat concat
  alias original_plus +

  def <<(str)
    return original_less_than_less_than(str) unless str.kind_of?(Exception)

    if !defined?(Rails) || !Rails.env.production?
      msg = "[DEPRECATION] String#<<(exception) should not be used.  Please use String#<<(exception.message) instead.  At #{caller[0]}"
      $log.warn msg if $log
      Kernel.warn msg
    end

    self.original_less_than_less_than(str.message)
  end

  def concat(str)
    return original_concat(str) unless str.kind_of?(Exception)

    if !defined?(Rails) || !Rails.env.production?
      msg = "[DEPRECATION] String#concat(exception) should not be used.  Please use String#concat(exception.message) instead.  At #{caller[0]}"
      $log.warn msg if $log
      Kernel.warn msg
    end

    self.original_concat(str.message)
  end

  def +(str)
    return original_plus(str) unless str.kind_of?(Exception)

    if !defined?(Rails) || !Rails.env.production?
      msg = "[DEPRECATION] String#+(exception) should not be used.  Please use String#+(exception.message) instead.  At #{caller[0]}"
      $log.warn msg if $log
      Kernel.warn msg
    end

    self.original_plus(str.message)
  end

  unless method_defined?(:each)
    include Enumerable

    def respond_to?(symbol, include_private=false)
      method = symbol.to_sym
      return false if method == :each || method == :to_a
      super
    end

    def each(*args, &block)
      if !defined?(Rails) || !Rails.env.production?
        msg = "[DEPRECATION] String#each has been removed from ruby 1.9.  Please use String#each_line instead.  At #{caller[0]}"
        $log.warn msg if $log
        Kernel.warn msg
      end

      self.each_line(*args, &block)
    end
  end

  unless method_defined?(:ord)
    def ord
      raise ArgumentError, "empty string" if self.length == 0
      return self[0]
    end
  end

  def miqEncode
    MIQEncode.encode(self)
  end

  ##############################################################################
  #
  # File activesupport-3.1.1/lib/active_support/core_ext/string/inflections.rb
  #
  ##############################################################################
  # ActiveSupport extensions included for non-Rails based code, where
  #   ActiveSupport itself cannot be included.
  ##############################################################################
  # Returns the plural form of the word in the string.
  #
  #   "post".pluralize             # => "posts"
  #   "octopus".pluralize          # => "octopi"
  #   "sheep".pluralize            # => "sheep"
  #   "words".pluralize            # => "words"
  #   "the blue mailman".pluralize # => "the blue mailmen"
  #   "CamelOctopus".pluralize     # => "CamelOctopi"
  def pluralize
    ActiveSupport::Inflector.pluralize(self)
  end unless method_defined?(:pluralize)

  # The reverse of +pluralize+, returns the singular form of a word in a string.
  #
  #   "posts".singularize            # => "post"
  #   "octopi".singularize           # => "octopus"
  #   "sheep".singularize            # => "sheep"
  #   "word".singularize             # => "word"
  #   "the blue mailmen".singularize # => "the blue mailman"
  #   "CamelOctopi".singularize      # => "CamelOctopus"
  def singularize
    ActiveSupport::Inflector.singularize(self)
  end unless method_defined?(:singularize)

  # +constantize+ tries to find a declared constant with the name specified
  # in the string. It raises a NameError when the name is not in CamelCase
  # or is not initialized.
  #
  # Examples
  #   "Module".constantize # => Module
  #   "Class".constantize  # => Class
  def constantize
    ActiveSupport::Inflector.constantize(self)
  end unless method_defined?(:constantize)

  # By default, +camelize+ converts strings to UpperCamelCase. If the argument to camelize
  # is set to <tt>:lower</tt> then camelize produces lowerCamelCase.
  #
  # +camelize+ will also convert '/' to '::' which is useful for converting paths to namespaces.
  #
  #   "active_record".camelize                # => "ActiveRecord"
  #   "active_record".camelize(:lower)        # => "activeRecord"
  #   "active_record/errors".camelize         # => "ActiveRecord::Errors"
  #   "active_record/errors".camelize(:lower) # => "activeRecord::Errors"
  def camelize(first_letter = :upper)
    case first_letter
      when :upper then ActiveSupport::Inflector.camelize(self, true)
      when :lower then ActiveSupport::Inflector.camelize(self, false)
    end
  end unless method_defined?(:camelize)

  # Capitalizes all the words and replaces some characters in the string to create
  # a nicer looking title. +titleize+ is meant for creating pretty output. It is not
  # used in the Rails internals.
  #
  # +titleize+ is also aliased as +titlecase+.
  #
  #   "man from the boondocks".titleize # => "Man From The Boondocks"
  #   "x-men: the last stand".titleize  # => "X Men: The Last Stand"
  def titleize
    ActiveSupport::Inflector.titleize(self)
  end unless method_defined?(:titleize)

  # The reverse of +camelize+. Makes an underscored, lowercase form from the expression in the string.
  #
  # +underscore+ will also change '::' to '/' to convert namespaces to paths.
  #
  #   "ActiveRecord".underscore         # => "active_record"
  #   "ActiveRecord::Errors".underscore # => active_record/errors
  def underscore
    ActiveSupport::Inflector.underscore(self)
  end unless method_defined?(:underscore)

  # Replaces underscores with dashes in the string.
  #
  #   "puni_puni" # => "puni-puni"
  def dasherize
    ActiveSupport::Inflector.dasherize(self)
  end unless method_defined?(:dasherize)

  # Removes the module part from the constant expression in the string.
  #
  #   "ActiveRecord::CoreExtensions::String::Inflections".demodulize # => "Inflections"
  #   "Inflections".demodulize                                       # => "Inflections"
  def demodulize
    ActiveSupport::Inflector.demodulize(self)
  end unless method_defined?(:demodulize)

  # Creates the name of a table like Rails does for models to table names. This method
  # uses the +pluralize+ method on the last word in the string.
  #
  #   "RawScaledScorer".tableize # => "raw_scaled_scorers"
  #   "egg_and_ham".tableize     # => "egg_and_hams"
  #   "fancyCategory".tableize   # => "fancy_categories"
  def tableize
    ActiveSupport::Inflector.tableize(self)
  end unless method_defined?(:tableize)

  # Create a class name from a plural table name like Rails does for table names to models.
  # Note that this returns a string and not a class. (To convert to an actual class
  # follow +classify+ with +constantize+.)
  #
  #   "egg_and_hams".classify # => "EggAndHam"
  #   "posts".classify        # => "Post"
  #
  # Singular names are not handled correctly.
  #
  #   "business".classify # => "Busines"
  def classify
    ActiveSupport::Inflector.classify(self)
  end unless method_defined?(:classify)

  # Capitalizes the first word, turns underscores into spaces, and strips '_id'.
  # Like +titleize+, this is meant for creating pretty output.
  #
  #   "employee_salary" # => "Employee salary"
  #   "author_id"       # => "Author"
  def humanize
    ActiveSupport::Inflector.humanize(self)
  end unless method_defined?(:humanize)

  # Creates a foreign key name from a class name.
  # +separate_class_name_and_id_with_underscore+ sets whether
  # the method should put '_' between the name and 'id'.
  #
  # Examples
  #   "Message".foreign_key        # => "message_id"
  #   "Message".foreign_key(false) # => "messageid"
  #   "Admin::Post".foreign_key    # => "post_id"
  def foreign_key(separate_class_name_and_id_with_underscore = true)
    ActiveSupport::Inflector.foreign_key(self, separate_class_name_and_id_with_underscore)
  end unless method_defined?(:foreign_key)

end
