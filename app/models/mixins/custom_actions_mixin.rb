module CustomActionsMixin
  extend ActiveSupport::Concern

  included do
    has_many :custom_button_sets, :as => :owner, :dependent => :destroy
    virtual_has_many :custom_buttons
    virtual_has_one :custom_actions, :class_name => "Hash"
    virtual_has_one :custom_action_buttons, :class_name => "Array"
  end

  def custom_actions
    {
      :buttons       => filter_by_visibility(custom_buttons).collect(&method(:serialize_button)),
      :button_groups => custom_button_sets_with_generics.collect do |button_set|
        button_set.serializable_hash.merge(
          :buttons => filter_by_visibility(button_set.children).collect(&method(:serialize_button))
        )
      end
    }
  end

  def custom_action_buttons
    filter_by_visibility(custom_buttons + custom_button_sets_with_generics.collect(&:children).flatten)
  end

  def generic_button_group
    generic_custom_buttons.select { |button| !button.parent.nil? }
  end

  def custom_button_sets_with_generics
    custom_button_sets + generic_button_group.map(&:parent).uniq.flatten
  end

  def custom_buttons
    generic_custom_buttons.select { |button| button.parent.nil? } + direct_custom_buttons
  end

  def direct_custom_buttons
    CustomButton.buttons_for(self).select { |b| b.parent.nil? }
  end

  def filter_by_visibility(buttons)
    buttons.select { |b| b.evaluate_visibility_expression_for(self) }
  end

  def serialize_button(button)
    button.expanded_serializable_hash.merge("enabled" => button.evaluate_enablement_expression_for(self))
  end

  def generic_custom_buttons
    CustomButton.buttons_for(self.class.base_model.name)
  end
end
