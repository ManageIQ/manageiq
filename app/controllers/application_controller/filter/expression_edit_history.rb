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

    def push(value)
      self.idx += 1
      array.slice!(idx..-1) if array[idx]
      array.push(copy_hash(value))
    end

    def rewind(direction)
      case direction
      when 'undo'
        if idx > 0
          self.idx -= 1
          return copy_hash(array[idx])
        end
      when 'redo'
        if idx < array.length - 1
          self.idx += 1
          return copy_hash(array[idx])
        end
      end
    end
  end
end
