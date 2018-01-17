class MiqAeWorkspace < ApplicationRecord
  serialize :workspace
  serialize :setters
  include UuidMixin

  def self.evmget(token, uri)
    workspace_from_token(token).evmget(uri)
  end

  def evmget(uri)
    workspace.varget(uri)
  end

  def self.evmset(token, uri, value)
    workspace_from_token(token).evmset(uri, value)
  end

  def evmset(uri, value)
    if workspace.varset(uri, value)
      self.setters ||= []
      self.setters << [uri, value]
      self.save!
    end
  end

  def self.display_name(number = 1)
    n_('Automation Workspace', 'Automation Workspaces', number)
  end

  def self.workspace_from_token(token)
    ws = MiqAeWorkspace.find_by(:guid => token)
    raise MiqAeException::WorkspaceNotFound, "Workspace Not Found for token=[#{token}]" if ws.nil?
    ws
  end
  private_class_method(:workspace_from_token)
end
