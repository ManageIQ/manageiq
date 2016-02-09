class ApplicationHelper::Toolbar::Basic
  include Singleton
  
  class << self
    extend Forwardable
    delegate [:model, :register, :buttons, :definition, :button_group] => :instance
  end

  attr_reader :definition

  private
  def register(name)
  end

  def model(_class)
  end

  def button_group(name, buttons)
    @definition[name] = buttons
  end

  def initialize
    @definition = {}
  end
end
