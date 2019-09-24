class MiqWidgetShortcut < ApplicationRecord
  belongs_to :miq_widget
  belongs_to :miq_shortcut

  def self.display_name(number = 1)
    n_('Widget Shortcut', 'Widget Shortcuts', number)
  end
end
