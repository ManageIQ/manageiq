class Symbol
  unless method_defined?(:to_i)
    def to_i
      to_s.to_i
    end
  end
end
