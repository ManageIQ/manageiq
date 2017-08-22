class PingController < ActionController::Base
  def index
    render :plain => 'pong', :status => 200
  end
end
