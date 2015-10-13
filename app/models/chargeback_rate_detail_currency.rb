class ChargebackRateDetailCurrency < ActiveRecord::Base
  belongs_to :chargeback_rate_detail

  #YAML.load_file(File.join(Rails.root, "db/fixtures/chargeback_rate_detail_currencies.yml"))
  validates :code, presence: true, length: { maximum: 100 }
  validates :name, presence: true, length: { maximum: 100 }
  validates :full_name, presence: true, length: { maximum: 100 }
  validates :symbol, presence: true, length: { maximum: 100 }
  validates :unicode_hex, presence: true, length: { minimum: 1 }
end
