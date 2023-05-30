class MiqExpression::InvalidTarget < MiqExpression::Target
  def initialize
    super(nil, nil, nil)
  end

  def column_type
    nil
  end

  def includes
    {}
  end

  def exclude_col_by_preprocess_options?(_options)
    false
  end

  def valid?
    false
  end
end
