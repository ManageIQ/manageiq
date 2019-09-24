class Category < Classification
  default_scope { is_category }

  def tags
    Tag.joins(:classification).where(:classifications => {:parent_id => id})
  end
end
