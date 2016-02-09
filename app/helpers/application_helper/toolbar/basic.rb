class ApplicationHelper::Toolbar::Basic
  include Singleton

  class << self
    extend Forwardable
    delegate %i(button select twostate separator definition button_group) => :instance
  end

  attr_reader :definition

  private

  def button_group(name, buttons)
    @definition[name] = buttons
  end

  def initialize
    @definition = {}
  end

  def button(id, icon, title, text, keys = {})
    generic_button(:button, id, icon, title, text, keys)
  end

  def select(id, icon, title, text, keys = {})
    generic_button(:buttonSelect, id, icon, title, text, keys)
  end

  def twostate(id, icon, title, text, keys = {})
    generic_button(:buttonTwoState, id, icon, title, text, keys)
  end

  def generic_button(type, id, icon, title, text, keys)
    {
      type   => id.to_s,
      :icon  => icon,
      :title => title,
      :text  => text
    }.merge(keys)
  end

  def separator
    {:separator => true}
  end
end
