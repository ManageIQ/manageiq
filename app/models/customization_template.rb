class CustomizationTemplate < ApplicationRecord
  include NewWithTypeStiMixin

  belongs_to :pxe_image_type
  has_many   :pxe_images, :through => :pxe_image_type

  validates :pxe_image_type, :presence => true, :unless => :system?
  validates :name, :uniqueness_when_changed => {:scope => :pxe_image_type}, :unless => :seeding?

  scope :with_pxe_image_type_id, ->(pxe_image_type_id) { where(:pxe_image_type_id => pxe_image_type_id) }
  scope :with_system,            ->(bool = true)       { where(:system => bool) }

  def seeding?
    system? && pxe_image_type.nil?
  end

  def self.seed_file_name
    @seed_file_name ||= Rails.root.join("db", "fixtures", "#{table_name}.yml")
  end

  def self.seed_data
    File.exist?(seed_file_name) ? YAML.load_file(seed_file_name) : []
  end

  def self.seed
    return unless self == base_class # Prevent subclasses from seeding

    current = in_my_region.where(:system => true).index_by(&:name)

    seed_data.each do |s|
      log_attrs = s.slice(:name, :type, :description)

      rec = current.delete(s[:name])
      if rec.nil?
        _log.info("Creating #{log_attrs.inspect}")
        create!(s)
      else
        rec.attributes = s.except(:type)
        if rec.changed?
          _log.info("Updating #{log_attrs.inspect}")
          rec.save!
        end
      end
    end

    current.values.each do |rec|
      log_attrs = rec.attributes.slice("id", "name", "type", "description").symbolize_keys
      _log.info("Deleting #{log_attrs.inspect}")
      rec.destroy
    end
  end

  # Applies ERB substitution to the script, and returns the result.  The
  #   evm variable is the hash of substitution options used inside the
  #   script.
  #
  # Example of use in script:  <% if evm[:addr_mode].first == 'static' %>
  def script_with_substitution(evm)
    self.class.substitute_erb(script, evm)
  end

  def self.substitute_erb(erb_text, evm)
    # The evm variable is the hash of options used inside a customization template
    #
    # example:  <% if evm[:addr_mode].first == 'static' %>
    require 'erb'
    ERB.new(erb_text).result(binding)
  end

  def self.kernel_args(_pxe_server, _pxe_image, _mac_address)
    {}
  end
end
