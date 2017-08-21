class PingController < ActionController::Base
  def index
    render :text => 'pong', :status => 200
  end
end
