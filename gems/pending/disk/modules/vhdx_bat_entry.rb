# encoding: US-ASCII

class VhdxBatEntry
  attr_reader :block, :state, :offset
  def initialize(block, state, offset)
    @block  = block - 1
    @state  = state
    @offset = offset
  end
end
