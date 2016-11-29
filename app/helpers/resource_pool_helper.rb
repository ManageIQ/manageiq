module ResourcePoolHelper
  include_concern 'TextualSummary'

  def calculate_rp_config(db_record)
    rp_config = []
    rp_config.push(:field       => _("Memory Reserve"),
                   :description => db_record.memory_reserve) unless db_record.memory_reserve.nil?
    rp_config.push(:field       => _("Memory Reserve Expand"),
                   :description => db_record.memory_reserve_expand) unless db_record.memory_reserve_expand.nil?
    unless db_record.memory_limit.nil?
      mem_limit = db_record.memory_limit
      mem_limit = "Unlimited" if db_record.memory_limit == -1
      rp_config.push(:field       => _("Memory Limit"),
                     :description => mem_limit)
    end
    rp_config.push(:field       => _("Memory Shares"),
                   :description => db_record.memory_shares) unless db_record.memory_shares.nil?
    rp_config.push(:field       => _("Memory Shares Level"),
                   :description => db_record.memory_shares_level) unless db_record.memory_shares_level.nil?
    rp_config.push(:field       => _("CPU Reserve"),
                   :description => db_record.cpu_reserve) unless db_record.cpu_reserve.nil?
    rp_config.push(:field       => _("CPU Reserve Expand"),
                   :description => db_record.cpu_reserve_expand) unless db_record.cpu_reserve_expand.nil?
    unless db_record.cpu_limit.nil?
      cpu_limit = db_record.cpu_limit
      cpu_limit = "Unlimited" if db_record.cpu_limit == -1
      rp_config.push(:field       => _("CPU Limit"),
                     :description => cpu_limit)
    end
    rp_config.push(:field       => _("CPU Shares"),
                   :description => db_record.cpu_shares) unless db_record.cpu_shares.nil?
    rp_config.push(:field       => _("CPU Shares Level"),
                   :description => db_record.cpu_shares_level) unless db_record.cpu_shares_level.nil?

    rp_config
  end
end
