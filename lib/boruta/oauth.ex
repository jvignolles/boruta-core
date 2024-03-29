defmodule Boruta.Oauth do
  @moduledoc """
  Boruta OAuth entrypoint, handles OAuth requests.

  Note : this module works in association with `Boruta.Oauth.Application` behaviour
  """

  alias Boruta.Oauth.Authorization
  alias Boruta.Oauth.CodeRequest
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.Introspect
  alias Boruta.Oauth.Request
  alias Boruta.Oauth.TokenRequest

  @doc """
  Triggers `token_success` in case of success and `token_error` in case of failure from the given `module`. Those functions are described in `Boruta.Oauth.Application` behaviour.
  """
  @spec token(conn :: Plug.Conn.t() | map(), module :: atom()) :: any()
  def token(conn, module) do
    with {:ok, request} <- Request.token_request(conn),
         {:ok, token} <- Authorization.token(request) do
      module.token_success(conn, token)
    else
      {:error, %Error{} = error} ->
        module.token_error(conn, error)
    end
  end

  @doc """
  Triggers `authorize_success` in case of success and `authorize_error` in case of failure from the given `module`. Those functions are described in `Boruta.Oauth.Application` behaviour.

  Note : resource owner must be provided as current_user assigns.
  """
  @spec authorize(conn :: Plug.Conn.t() | map(), module :: atom()) :: any()
  def authorize(conn, module) do
    with {:ok, request} <- Request.authorize_request(conn),
         {:ok, token} <- Authorization.token(request) do
      module.authorize_success(conn, token)
    else
      {:error, %Error{} = error} ->
        with {:ok, request} <- Request.authorize_request(conn) do
          module.authorize_error(conn, error_with_format(request, error))
        else
          _ ->
            module.authorize_error(conn, error)
        end
    end
  end

  @doc """
  Triggers `introspect_success` in case of success and `introspect_error` in case of failure from the given `module`. Those functions are described in `Boruta.Oauth.Application` behaviour.
  """
  @spec introspect(conn :: Plug.Conn.t() | map(), module :: atom()) :: any()
  def introspect(conn, module) do
    with {:ok, request} <- Request.introspect_request(conn),
         {:ok, response} <- Introspect.token(request) do
      module.introspect_success(conn, response)
    else
      {:error, %Error{} = error} ->
        module.introspect_error(conn, error)
    end
  end

  # private
  defp error_with_format(%CodeRequest{redirect_uri: redirect_uri}, %Error{} = error) do
    %{error | format: :query, redirect_uri: redirect_uri}
  end
  defp error_with_format(%TokenRequest{redirect_uri: redirect_uri}, %Error{} = error) do
    %{error | format: :fragment, redirect_uri: redirect_uri}
  end
  defp error_with_format(_, error), do: error
end
