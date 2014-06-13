class VdiControllerController < VdiBaseController

  def index
    process_index
  end

  def show
    process_show
  end

  def show_list
    process_show_list
  end

end
