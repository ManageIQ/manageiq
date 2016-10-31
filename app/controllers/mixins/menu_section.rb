module Mixins::MenuSection
  extend ActiveSupport::Concern

  def menu_section_id(_parms)
    self.class.instance_eval { @section_id }
  end

  class_methods do
    def menu_section(section_id)
      @section_id = section_id
    end
  end
end
