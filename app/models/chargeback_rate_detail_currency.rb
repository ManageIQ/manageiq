class ChargebackRateDetailCurrency < ApplicationRecord
  belongs_to :chargeback_rate_detail

  # YAML.load_file(File.join(Rails.root, "db/fixtures/chargeback_rate_detail_currencies.yml"))
  validates :code,        :presence => true, :length => {:maximum => 100}
  validates :name,        :presence => true, :length => {:maximum => 100}
  validates :full_name,   :presence => true, :length => {:maximum => 100}
  validates :symbol,      :presence => true, :length => {:maximum => 100}
  validates :unicode_hex, :presence => true, :length => {:minimum => 1}

  has_many :chargeback_rate_detail, :foreign_key => "chargeback_rate_detail_currency_id"

  def self.currencies_for_select
    # Return a hash where the keys are the possible currencies and the values are their ids
    ChargebackRateDetailCurrency.all.each_with_object({}) do |currency, hsh|
      currency_code = "#{currency.symbol} [#{currency.full_name}]"
      hsh[currency_code] = currency.id
    end
  end

  def self.seed
    fixture_file_currency = File.join(FIXTURE_DIR, 'chargeback_rate_detail_currencies.yml')
    if File.exist?(fixture_file_currency)
      fixture = YAML.load_file(fixture_file_currency)
      fixture_mtime_currency = File.mtime(fixture_file_currency).utc
      fixture.each do |cbr|
        rec = ChargebackRateDetailCurrency.find_by(:name => cbr[:name])
        if rec.nil?
          _log.info("Creating [#{cbr[:name]}] with symbols=[#{cbr[:symbol]}]!!!!")
          rec = ChargebackRateDetailCurrency.create(cbr)
        elsif fixture_mtime_currency > rec.created_at
          _log.info("Updating [#{cbr[:name]}] with symbols=[#{cbr[:symbol]}]")
          rec.update_attributes(cbr)
          rec.created_at = fixture_mtime_currency
          rec.save
        end
      end
    end
  end
end
