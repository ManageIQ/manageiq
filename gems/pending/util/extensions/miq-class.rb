class Class
  def hierarchy
    ancestors.grep(Class)
  end

  alias subclass_of? <
  alias is_subclass_of? subclass_of?

  alias is_or_subclass_of? <=

  alias superclass_of? >
  alias is_superclass_of? superclass_of?

  alias is_or_superclass_of? >=
end
