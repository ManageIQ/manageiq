module MiqAeModelBase
  STATE_ATTRIBUTES = %w(on_entry on_exit on_error max_retries max_time collect message)

  EXPORT_EXCLUDE_KEYS = %w(id namespace_id parent_id class_id method_id created_on updated_on updated_by_skip reserved data field_id instance_id fqname)
  extend ActiveSupport::Concern

  FALSE_VALUES = [false, 0, '0', 'f', 'F', 'false', 'FALSE'].to_set
  TRUE_VALUES = [true, 1, '1', 't', 'T', 'true', 'TRUE'].to_set

  included do
    include ActiveModel::AttributeMethods
    include ActiveModel::Dirty
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    include MiqAeSetUserInfoMixin
    validates_presence_of :name
    validates_format_of :name, :with => /\A[A-Za-z0-9_\.\-\$]+\z/i
  end

  module ClassMethods
    def new_with_hash(hash)
      new(hash)
    end

    def human_attribute_name(attribute_key_name, _options = {})
      attribute_key_name.to_s.humanize
    end

    def expose_columns(*methods)
      methods.each do |m|
        define_method(m) do
          self[m]
        end

        define_method("#{m}=") do |value|
          unless self[m] == value
            send("#{m}_will_change!")
            self[m] = value
          end
        end

        define_method("#{m}?") do
          self[m].present?
        end

        define_attribute_method m
      end
    end

    def create(options = {})
      options.class == Array ? create_with_array(options) : create_with_hash(options)
    end

    def create_with_hash(options = {}, func = :save)
      new_with_hash(options).tap(&func)
    end

    def create_with_array(array = [], func = :save)
      array.collect { |hash| create_with_hash(hash, func) }
    end

    def create!(options = {})
      options.class == Array ? create_with_array(options, :save!) : create_with_hash(options, :save!)
    end

    def build(options = {})
      options.class == Array ? build_with_array(options) : build_with_hash(options)
    end

    def build_with_array(array)
      array.collect { |hash| build_with_hash(hash) }
    end

    def build_with_hash(options = {})
      new_with_hash(options)
    end

    def column_names
      %w(name display_name description)
    end

    def find_all_by_id(ids, *_args)
      ids.collect { |i| find(i) }
    end

    def transaction
      yield
    end
  end

  def persisted?
    id
  end

  def attributes
    @attributes.clone
  end

  def [](key)
    @attributes[key]
  end

  def []=(key, value)
    @attributes[key] = value
  end

  def inspect
    to_s
  end

  def new_record?
    id.nil?
  end

  def initialize(options = {})
    @attributes = HashWithIndifferentAccess.new(options)
  end

  def update_attributes(hash)
    hash = HashWithIndifferentAccess.new(hash)
    hash.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=", true) }
    save!
  end

  def update_attributes!(hash)
    update_attributes(hash)
  end

  def export_attributes
    attributes.except(*EXPORT_EXCLUDE_KEYS)
  end

  def export_non_blank_attributes
    export_attributes.delete_if { |_, v| v.blank? }
  end

  def children_deleted
    @children_deleted = true
  end

  def updated_by_ui
    @stats ||= self.class.file_attributes(fqname)
    @stats[:updated_by]
  end

  def updated_on_ui
    @stats ||= self.class.file_attributes(fqname)
    @stats[:updated_on]
  end

  def children_deleted?
    @children_deleted
  end

  def save!
    save.tap { |result| raise ActiveRecord::RecordInvalid, self unless result }
  end

  def changes_applied
    @previously_changed = changes
    @changed_attributes = HashWithIndifferentAccess.new
  end

  def ==(other)
    other.id.eql?(id)
  end
end
