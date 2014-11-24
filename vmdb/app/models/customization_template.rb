class CustomizationTemplate < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  belongs_to :pxe_image_type
  has_many   :pxe_images, :through => :pxe_image_type

  validates :pxe_image_type, :presence => true, :unless => :system?
  #validates :name,           :uniqueness => { :scope => :pxe_image_type }

  def self.seed_file_name
    @seed_file_name ||= Rails.root.join("db", "fixtures", "#{self.table_name}.yml")
  end

  def self.seed_data
    File.exist?(seed_file_name) ? YAML.load_file(seed_file_name) : []
  end

  def self.seed
    return unless self == base_class # Prevent subclasses from seeding

    log_header = "MIQ(#{self.name}.seed)"
    MiqRegion.my_region.lock do
      current = self.where(:system => true).index_by(&:name)

      seed_data.each do |s|
        log_attrs = s.slice(:name, :type, :description)

        rec = current.delete(s[:name])
        if rec.nil?
          $log.info("#{log_header} Creating #{log_attrs.inspect}")
          self.create!(s)
        else
          rec.attributes = s.except(:type)
          if rec.changed?
            $log.info("#{log_header} Updating #{log_attrs.inspect}")
            rec.save!
          end
        end
      end

      current.values.each do |rec|
        log_attrs = rec.attributes.slice("id", "name", "type", "description").symbolize_keys
        $log.info("#{log_header} Deleting #{log_attrs.inspect}")
        rec.destroy
      end
    end
  end

  # Applies ERB substitution to the script, and returns the result.  The
  #   evm variable is the hash of substitution options used inside the
  #   script.
  #
  # Example of use in script:  <% if evm[:addr_mode].first == 'static' %>
  def script_with_substitution(evm)
    self.class.substitute_erb(self.script, evm)
  end

  def self.substitute_erb(erb_text, evm)
    # The evm variable is the hash of options used inside a customization template
    #
    # example:  <% if evm[:addr_mode].first == 'static' %>
    require 'erb'
    ERB.new(erb_text).result(binding)
  end
end
