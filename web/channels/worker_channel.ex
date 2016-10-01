defmodule MicrocrawlerWebapp.WorkerChannel do
  use Phoenix.Channel

  def join("worker:lobby", _message, socket) do
    {:ok, %{msg: "Welcome!"}, socket}
  end

  def join("worker:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_in(event, payload, socket) do
      IO.puts "Received event"
      IO.inspect event
      IO.inspect payload
      {:noreply, socket}
    end
end
