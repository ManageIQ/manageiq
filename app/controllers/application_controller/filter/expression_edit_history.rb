module ApplicationController::Filter
  ExpressionEditHistory = Struct.new(
    :array,
    :idx
  ) do
    def initialize(*args)
      super
      self.idx ||= 0
    end

    def reset(value)
      self.array = [copy_hash(value)]
      self.idx = 0
    end
  end
end
