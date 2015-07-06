class CimVmdbAgent < StorageManager

  has_many  :top_managed_elements,
        :class_name   => "MiqCimInstance",
        :foreign_key  => "agent_top_id"

  has_many  :managed_elements,
        :class_name   => "MiqCimInstance",
        :foreign_key  => "agent_id"

end
