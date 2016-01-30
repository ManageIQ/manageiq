class Symbol
  unless method_defined?(:to_i)
    def to_i
      numeric_string = to_s
      numeric_string.to_i
    end
  end
end
