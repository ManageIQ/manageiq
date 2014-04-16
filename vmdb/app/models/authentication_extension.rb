class AuthenticationExtension < ActiveRecord::Base
  extend ActiveHash::Associations::ActiveRecordExtensions
  belongs_to :authentication
  belongs_to_active_hash :authentication_extension_type

  validate :value_contains_correct_data_type
  validates_uniqueness_of :id, :scope => [:authentication_id, :authentication_extension_type_id]

  def value
    @value ||= fetch_value
  end

  def value=(a_value)
    if data_type == "text"
      self.value_text = a_value.to_s
    else
      self.value_string = a_value.to_s
    end
    # cache the provided value as-is
    @value = a_value
  end

  def value_contains_correct_data_type
    if data_type == "text"
    else
      # make sure the raw value converts back to the same string
      if fetch_value.to_s != value_string
        errors.add(:value, "must be #{data_type} value")
      end

      options = authentication_extension_type.options
      unless options.empty? || options.keys.include?(fetch_value)
        errors.add(:value, "must be one of #{options.values}")
      end
    end
  end

  def method_missing(method, *args, &block)
    if !method.to_s.end_with?("=") && authentication_extension_type && authentication_extension_type.respond_to?(method)
      # don't allow setters to be delegated to auth_ext_type
      authentication_extension_type.send(method, *args, &block)
    else
      super
    end
  end

  private
  def fetch_value
    self.send("fetch_value_#{data_type}")
  end

  def fetch_value_string
    value_string
  end

  def fetch_value_symbol
    with_value_string {|s| s.to_sym }
  end

  def fetch_value_text
    value_text
  end

  def fetch_value_int
    with_value_string {|s| s.to_i }
  end

  def fetch_value_float
    with_value_string {|s| s.to_f }
  end

  def fetch_value_date
    with_value_string {|s| Date.parse(s) }
  end

  def fetch_value_boolean
    value_string && value_string == "true"
  end

  def with_value_string
    if value_string && !value_string.empty?
      yield(value_string)
    end
  end

  def delegate_to_type(method)
    authentication_extension_type.send(method) if authentication_extension_type && authentication_extension_type.respond_to?(method)
  end
end
