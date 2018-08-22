module CustomActionsMixin
  extend ActiveSupport::Concern

  included do
    has_many :custom_button_sets, :as => :owner, :dependent => :destroy
    has_many :custom_button_events, -> { where(:type => "CustomButtonEvent") }, :class_name => "EventStream", :foreign_key => :target_id
    virtual_has_many :custom_buttons
    virtual_has_one :custom_actions, :class_name => "Hash"
    virtual_has_one :custom_action_buttons, :class_name => "Array"
  end

  def custom_actions(applies_to = self)
    {
      :buttons       => serialize_buttons_if_visible(custom_buttons, applies_to),
      :button_groups => custom_button_sets_with_generics.collect do |button_set|
        button_set.serializable_hash.merge(
          :buttons => serialize_buttons_if_visible(button_set.children, applies_to)
        )
      end.reject { |button_group| button_group[:buttons].empty? }
    }
  end

  def custom_action_buttons(applies_to = self)
    filter_by_visibility(custom_buttons + custom_button_sets_with_generics.collect(&:children).flatten, applies_to)
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

  def filter_by_visibility(buttons, applies_to = self)
    buttons.select { |b| b.evaluate_visibility_expression_for(target_for_expression(b, applies_to)) }
  end

  def serialize_button(button, applies_to = self)
    obj = target_for_expression(button, applies_to)
    button.expanded_serializable_hash.merge("enabled" => button.evaluate_enablement_expression_for(obj))
  end

  def generic_custom_buttons
    CustomButton.buttons_for(self.class.base_model.name)
  end

  private

  def serialize_buttons_if_visible(buttons, applies_to)
    filter_by_visibility(buttons, applies_to).collect { |button| serialize_button(button, applies_to) }
  end

  def target_for_expression(button, applies_to)
    button.applies_to_class == applies_to.class.base_model.name ? applies_to : self
  end
end
