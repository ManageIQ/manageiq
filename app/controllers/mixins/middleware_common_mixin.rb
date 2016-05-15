module MiddlewareCommonMixin
  extend ActiveSupport::Concern
  include AuthorizationMessagesMixin

  def show_list
    process_show_list
  end

  def index
    redirect_to :action => 'show_list'
  end

  private

  def display_name
    ui_lookup(:tables => @record.class.base_class.name)
  end

  def listicon_image(item, _view)
    icon = item.decorate.try(:listicon_image)
    "100/#{icon}.png"
  end

end