class PodTerminalChannel < ApplicationCable::Channel
  def subscribed
    stream_from "pod_terminal_#{params[:pod_id]}"
  end

  def input(data)
    session = POD_SESSIONS[params[:pod_id].to_s]
    return unless session
    cg = ContainerGroup.find(params[:pod_id])
    cg.send_terminal_input(data["data"])   # dispatches through the model, not raw pty_in.write
  end
end