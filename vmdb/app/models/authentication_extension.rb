class AuthenticationExtension < ActiveRecord::Base
  extend ActiveHash::Associations::ActiveRecordExtensions
  belongs_to :authentication
  belongs_to_active_hash :authentication_extension_type

  validate :value_contains_correct_data_type
  validates_uniqueness_of :id, :scope => [:authentication_id, :authentication_extension_type_id]

  delegate :authtype, :name, :key, :data_type, :options, :to => :authentication_extension_type

  def value
    @value ||= fetch_value
  end

  def value=(a_value)
    # TODO: need to provide 2-way encryption for password values
    self.value_string = a_value.to_s
    # cache the provided value as-is
    @value = a_value
  end

  def value_contains_correct_data_type
    # make sure the raw value converts back to the same string
    errors.add(:value, "must be #{data_type} value") if fetch_value.to_s != value_string
    errors.add(:value, "must be one of #{options.values}") if data_type == "select"
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

  def fetch_value_select
    fetch_value_symbol
  end

  def fetch_value_password
    # TODO: need to provide 2-way encryption for password values
    fetch_value_string
  end

  def fetch_value_text
    fetch_value_string
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
end
