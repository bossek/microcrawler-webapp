defmodule MicrocrawlerWebapp.WorkerSocket do
  use Phoenix.Socket

  require Logger

  alias MicrocrawlerWebapp.Users

  ## Channels
  channel "worker:*", MicrocrawlerWebapp.WorkerChannel

  ## Transports
  transport :websocket, MicrocrawlerWebapp.Transports.WebSocket
  transport :longpoll, Phoenix.Transports.LongPoll

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  def connect(%{"guardian_token" => jwt}, socket) do
    case Guardian.decode_and_verify(jwt) do
      {:ok, %{"email" => email, "token" => token}} ->
        validate(email, token, socket)
      error ->
        Logger.debug(
          "worker jwt '#{jwt}' verification failed " <>
          "with result: #{inspect(error)}"
        )
        :error
    end
  end

  defp validate(email, token, socket) do
    case Users.get(email) do
      {:ok, user} ->
        case user.token == token do
          true ->
            {:ok, socket}
          false ->
            Logger.debug "worker expired token '#{token}' for user '#{email}'"
            :error
        end
      error ->
        Logger.debug "worker user '#{email}' not found: #{inspect(error)}"
        :error
    end
  end

  # Socket id's are topics that allow you to identify all sockets
  # for a given user:
  #
  #     def id(socket), do: "users_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     MicrocrawlerWebapp.Endpoint.broadcast(
  #       "users_socket:#{user.id}", "disconnect", %{}
  #     )
  #
  # Returning `nil` makes this socket anonymous.
  def id(_socket), do: nil
end
