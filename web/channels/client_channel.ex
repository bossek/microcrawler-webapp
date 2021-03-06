defmodule MicrocrawlerWebapp.ClientChannel do
  @moduledoc """
  TODO
  """

  use Phoenix.Channel

  require Logger

  alias MicrocrawlerWebapp.ActiveWorkers
  alias MicrocrawlerWebapp.Couchbase
  alias MicrocrawlerWebapp.Endpoint
  alias MicrocrawlerWebapp.WorkQueue

  def clear_worker_list do
    Endpoint.broadcast("client:lobby", "clear_worker_list", %{})
  end

  def update_worker(worker) do
    Endpoint.broadcast("client:lobby", "update_worker", worker)
  end

  def remove_worker(worker) do
    Endpoint.broadcast("client:lobby", "remove_worker", worker)
  end

  def join("client:lobby", payload, socket) do
    Logger.debug "Received join - client:lobby"
    Logger.debug Poison.encode_to_iodata!(payload, pretty: true)
    Logger.debug inspect(self())

    send(self(), :send_joined_workers)

    {:ok, %{msg: "Welcome!"}, socket}
  end

  def join("client:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_in("enqueue", payload_in, socket) do
    Logger.debug "Received event - enqueue"

    payload = payload_in
    |> Map.put_new("uuid", UUID.uuid4())
    |> Map.put_new("type", "url")
    |> Map.put("crawler", String.replace(Map.get(payload_in, "crawler"), "microcrawler-crawler-", ""))

    key = "url-#{Map.fetch!(payload, "crawler")}-#{Map.fetch!(payload, "url")}"
    key_hash = Base.encode16(:crypto.hash(:sha256, key))

    case Couchbase.get(key_hash) do
      %{"error" => "The key does not exist on the server"} ->
        Couchbase.set(key_hash, payload)
        payload = Poison.encode!(payload)
        WorkQueue.open!
        |> WorkQueue.publish!(payload)
        |> WorkQueue.close
      _ -> nil
    end

    {:noreply, socket}
  end

  def handle_info(:send_joined_workers, socket) do
    push socket, "clear_worker_list", %{}
    Enum.each(ActiveWorkers.joined_workers, fn(worker) ->
      push socket, "update_worker", worker
    end)
    {:noreply, socket}
  end

  def handle_info(msg, socket) do
    Logger.debug inspect(msg)
    Logger.debug inspect(self())

    {:noreply, socket}
  end

  def terminate(reason, socket) do
    Logger.debug inspect(reason)
    Logger.debug inspect(self())
    Logger.debug inspect(socket)
    :ok
  end
end
