require "money"

class ChargebackRateDetailCurrency < ApplicationRecord
  belongs_to :chargeback_rate_detail

  validates :code,        :presence => true, :length => {:maximum => 100}
  validates :name,        :presence => true, :length => {:maximum => 100}
  validates :full_name,   :presence => true, :length => {:maximum => 100}
  validates :symbol,      :presence => true, :length => {:maximum => 100}

  has_many :chargeback_rate_detail, :foreign_key => "chargeback_rate_detail_currency_id"

  self.table_name = 'currencies'

  CURRENCY_FILE = "/currency_iso.json".freeze
  FIXTURE_DIR = Money::Currency::Loader::DATA_PATH.freeze

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
    parse_currency_file.transform_values.map do |x|
      {:code => x[:iso_code], :name => x[:name], :full_name => x[:name], :symbol => x[:symbol]}
    end
  end

  def self.parse_currency_file
    json = File.read(currency_file_source)
    json.force_encoding(::Encoding::UTF_8) if defined?(::Encoding)
    JSON.parse(json, :symbolize_names => true)
  end

  def self.seed
    db_currencies = ChargebackRateDetailCurrency.all.index_by(&:code)
    if File.exist?(currency_file_source)
      fixture_mtime_currency = File.mtime(currency_file_source).utc
      currencies.each do |currency|
        if currency[:symbol].blank?
          _log.info("Skipping [#{currency[:code]}] due to missing symbol")
          next
        end

        rec = db_currencies[currency[:code]]
        if rec.nil?
          _log.info("Creating [#{currency[:code]}] with symbols=[#{currency[:symbol]}]")
          ChargebackRateDetailCurrency.create!(currency)
        elsif fixture_mtime_currency > rec.created_at
          rec.attributes = currency
          if rec.changed?
            _log.info("Updating [#{currency[:code]}] with symbols=[#{currency[:symbol]}]")
            rec.update!(:created_at => fixture_mtime_currency)
          end
        end
      end
    end
  end
end
