class ChargebackRateDetailCurrency < ApplicationRecord
  belongs_to :chargeback_rate_detail

  validates :code,        :presence => true, :length => {:maximum => 100}
  validates :name,        :presence => true, :length => {:maximum => 100}
  validates :full_name,   :presence => true, :length => {:maximum => 100}
  validates :symbol,      :presence => true, :length => {:maximum => 100}

  has_many :chargeback_rate_detail, :foreign_key => "chargeback_rate_detail_currency_id"

  CURRENCY_FILE = "chargeback_rate_detail_currencies.yml".freeze

  def self.currencies_for_select
    # Return a hash where the keys are the possible currencies and the values are their ids
    ChargebackRateDetailCurrency.all.each_with_object({}) do |currency, hsh|
      currency_code = "#{currency.symbol} [#{currency.full_name}]"
      hsh[currency_code] = currency.id
    end
  end

  def self.currency_file_source
    File.join(FIXTURE_DIR, CURRENCY_FILE)
  end

  def self.currencies
    YAML.load_file(currency_file_source)
  end

  def self.seed
    if File.exist?(currency_file_source)
      fixture_mtime_currency = File.mtime(currency_file_source).utc
      currencies.each do |cbr|
        rec = ChargebackRateDetailCurrency.find_by(:name => cbr[:name])
        if rec.nil?
          _log.info("Creating [#{cbr[:name]}] with symbols=[#{cbr[:symbol]}]")
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
