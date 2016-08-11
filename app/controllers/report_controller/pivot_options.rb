class ReportController
  # For groupby fields in repor
  PivotOptions = Struct.new(:by1, :by2, :by3, :by4) do
    def initialize(by1 = NOTHING_STRING, by2 = NOTHING_STRING, by3 = NOTHING_STRING, by4 = NOTHING_STRING)
      super
    end

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

    def update(params)
      if params[:chosen_pivot1] && params[:chosen_pivot1] != by1
        self.by1 = params[:chosen_pivot1]
        if params[:chosen_pivot1] == NOTHING_STRING
          self.by2 = NOTHING_STRING
          self.by3 = NOTHING_STRING
          self.by4 = NOTHING_STRING
        elsif params[:chosen_pivot1] == by2
          self.by2 = by3
          self.by3 = by4
          self.by4 = NOTHING_STRING
        elsif params[:chosen_pivot1] == by3
          self.by3 = by4
          self.by4 = NOTHING_STRING
        end
      elsif params[:chosen_pivot2] && params[:chosen_pivot2] != by2
        self.by2 = params[:chosen_pivot2]
        if params[:chosen_pivot2] == NOTHING_STRING
          self.by3 = NOTHING_STRING
          self.by4 = NOTHING_STRING
        elsif params[:chosen_pivot2] == by3
          self.by3 = by4
          self.by4 = NOTHING_STRING
        elsif params[:chosen_pivot2] == by4
          self.by4 = NOTHING_STRING
        end
      elsif params[:chosen_pivot3] && params[:chosen_pivot3] != by3
        self.by3 = params[:chosen_pivot3]
        if params[:chosen_pivot3] == NOTHING_STRING || params[:chosen_pivot3] == by4
          self.by4 = NOTHING_STRING
        end
      elsif params[:chosen_pivot4]
        self.by4 = params[:chosen_pivot4]
      end
    end

    def drop_from_selection(item)
      # Compress the pivotby fields if being moved left
      if item == by1
        self.by1 = by2
        self.by2 = by3
        self.by3 = NOTHING_STRING
      elsif item == by2
        self.by2 = by3
        self.by3 = NOTHING_STRING
      elsif item == by3
        self.by3 = NOTHING_STRING
      end
    end
  end
end
