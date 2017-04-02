class ShowbackTariff < ApplicationRecord
  has_many :showback_rates, :dependent => :destroy, :inverse_of => :showback_tariff
  belongs_to :resource, :polymorphic => true
  validates :name, :presence => true
  validates :description, :presence => true
  validates :resource, :presence => true

  #
  # Seeding one global tariff in the system that will be used as a fallback
  #
  def self.seed
    seed_data.each do |tariff_attributes|
      tariff_attributes_name = tariff_attributes[:name]
      tariff_attributes_description = tariff_attributes[:description]
      tariff_attributes_resource = tariff_attributes[:resource_type].constantize.send(:find_by, :name => tariff_attributes[:resource_name])

      next if ShowbackTariff.find_by(:name => tariff_attributes_name, :resource => tariff_attributes_resource)
      log_attrs = tariff_attributes.slice(:name, :description, :resource_name, :resource_type)
      _log.info("Creating consumption tariff with parameters #{log_attrs.inspect}")
      _log.info("Creating #{tariff_attributes_name} consumption tariff...")
      tariff_new = create(:name => tariff_attributes_name, :description => tariff_attributes_description, :resource => tariff_attributes_resource)
      tariff_new.save
      _log.info("Creating #{tariff_attributes_name} consumption tariff... Complete")
    end
  end

  private

  def self.seed_file_name
    @seed_file_name ||= Rails.root.join("db", "fixtures", "#{table_name}.yml")
  end

  def self.seed_data
    File.exist?(seed_file_name) ? YAML.load_file(seed_file_name) : []
  end
end
