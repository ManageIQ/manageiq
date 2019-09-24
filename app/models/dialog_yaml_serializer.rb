class DialogYamlSerializer < DialogSerializer
  def serialize(dialogs)
    super.to_yaml
  end
end
