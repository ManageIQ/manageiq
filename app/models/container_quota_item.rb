class ContainerQuotaItem < ApplicationRecord
  belongs_to :container_quota
  BINARY_SUFFICES = ["Ki", "Mi", "Gi", "Ti", "Pi", "Ei"].freeze
  SI_SUFFICES = ["K", "M", "G", "T", "P", "E"].freeze

  def normalize_field_for_chargeback(field_sym)
    raw_field = send(field_sym)
    case resource
      when "cpu" # 1000m = 1 core - convert to cores
        raw_field.end_with?("m") ?  raw_field.chomp("m").to_i / 1000 : raw_field.to_i
      when "memory" # could be "Ki", "Mi", "Gi", "Ti", "Pi", "Ei" or in bytes - convert to bytes
        suffix = raw_field[-2..-1]
        power = BINARY_SUFFICES.index(suffix)
        if power.present?
          raw_field.chomp(suffix).to_i * (1024**power)
        else
          suffix = raw_field[-1]
          power = SI_SUFFICES.index(suffix)
          if power.present?
            raw_field.chomp(suffix).to_i * (1000**power)
          else
            raw_field.to_i
          end
        end
      else # probably an object count
        raw_field.to_i
    end
  end
end
