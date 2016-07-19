class ReportController
  # For groupby fields in repor
  PivotOptions = Struct.new(:by1, :by2, :by3, :by4) do
    def options=(options)
      @opts = {1 => options}
    end

    def options1
      @opts[1]
    end

    def options2
      @opts[2] ||= options1.reject { |g| g[1] == by1 }
    end

    def options3
      @opts[3] ||= options2.reject { |g| g[1] == by2 }
    end

    def options4
      @opts[4] ||= options3.reject { |g| g[1] == by3 }
    end
  end
end
