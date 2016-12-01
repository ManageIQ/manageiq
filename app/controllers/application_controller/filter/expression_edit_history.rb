module ApplicationController::Filter
  ExpressionEditHistory = Struct.new(
    :array,
    :idx
  ) do
    def initialize(*args)
      super
      self.idx ||= 0
    end
  end
end
