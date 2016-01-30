class Category < Classification
  default_scope { where(:parent_id => 0) }

  def tags
    Tag.joins(:classification).where(:classifications => {:parent_id => id})
  end
end
