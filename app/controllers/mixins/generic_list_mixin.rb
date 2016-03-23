module Mixins
  module GenericListMixin
    def index
      redirect_to :action => 'show_list'
    end

    def show_list
      process_show_list
    end
  end
end
