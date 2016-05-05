class ConsumptionController < ApplicationController
  def show
    @layout     = "consumption"
    @showtype   = "consumption"
    @message    = "Brace yourselves ... CONSUMPTION is coming !"
  end
end
