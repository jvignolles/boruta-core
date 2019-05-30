defmodule Boruta.Oauth.Request do
  alias Boruta.BasicAuth
  alias Boruta.Oauth.AuthorizationCodeRequest
  alias Boruta.Oauth.ClientCredentialsRequest
  alias Boruta.Oauth.CodeRequest
  alias Boruta.Oauth.ImplicitRequest
  alias Boruta.Oauth.ResourceOwnerPasswordCredentialsRequest
  alias Boruta.Oauth.Validator

  # Handle Plug.Conn to extract header authorization (could not implement that as a guard)
  def token_request(%Plug.Conn{req_headers: req_headers, body_params: %{} = body_params}) do
    with {"authorization", authorization_header} <- Enum.find(
      req_headers,
      fn (header) -> elem(header, 0) == "authorization" end
    ) do
      token_request(%{
        req_headers: [{"authorization", authorization_header}],
        body_params: %{} = body_params
      })
    else
      nil ->
        token_request(%{body_params: %{} = body_params})
    end
  end

  def token_request(%{req_headers: [{"authorization", authorization_header}], body_params: %{} = body_params}) do
    with {:ok, [client_id, client_secret]} <- BasicAuth.decode(authorization_header),
         %{} = params <- Validator.validate(
           Enum.into(body_params, %{"client_id" => client_id, "client_secret" => client_secret})
         ) do
      build_request(params)
    else
      {:error, error} ->
        {:bad_request, %{error: "invalid_request", error_description: error}}
    end
  end
  def token_request(%{body_params: %{} = body_params}) do
    with %{} = params <- Validator.validate(body_params) do
      build_request(params)
    else
      {:error, error_description} ->
        {:bad_request, %{error: "invalid_request", error_description: error_description}}
    end
  end
  def token_request(_) do
    {:bad_request, %{error: "invalid_request", error_description: "Must provide body_params."}}
  end

  def authorize_request(%{query_params: query_params, assigns: %{current_user: user}}) do
    with %{} = params <- Validator.validate(query_params) do
      build_request(Enum.into(params, %{"user" => user}))
    else
      {:error, error_description} ->
        {:bad_request, %{error: "invalid_request", error_description: error_description}}
    end
  end
  def authorize_request(_) do
    {:bad_request, %{error: "invalid_request", error_description: "Must provide query_params and assigned current_user."}}
  end

  # private
  defp build_request(%{"grant_type" => "client_credentials"} = params) do
    {:ok, struct(ClientCredentialsRequest, %{
      client_id: params["client_id"],
      client_secret: params["client_secret"]
    })}
  end
  defp build_request(%{"grant_type" => "password"} = params) do
    {:ok, struct(ResourceOwnerPasswordCredentialsRequest, %{
      client_id: params["client_id"],
      client_secret: params["client_secret"],
      username: params["username"],
      password: params["password"]
    })}
  end
  defp build_request(%{"grant_type" => "authorization_code"} = params) do
    {:ok, struct(AuthorizationCodeRequest, %{
      client_id: params["client_id"],
      code: params["code"],
      redirect_uri: params["redirect_uri"]
    })}
  end

  defp build_request(%{"response_type" => "token"} = params) do
    {:ok, struct(ImplicitRequest, %{
      client_id: params["client_id"],
      redirect_uri: params["redirect_uri"],
      user: params["user"]
    })}
  end
  defp build_request(%{"response_type" => "code"} = params) do
    {:ok, struct(CodeRequest, %{
      client_id: params["client_id"],
      redirect_uri: params["redirect_uri"],
      user: params["user"]
    })}
  end
end