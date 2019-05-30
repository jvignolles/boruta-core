defprotocol Boruta.Oauth.Authorization do
  def token(request)
end

defmodule Boruta.Oauth.Authorization.Base do
  alias Boruta.Coherence.User
  alias Boruta.Oauth.Client
  alias Boruta.Oauth.Token
  alias Boruta.Repo

  def client(id: id, secret: secret) do
    with %Client{} = client <- Repo.get_by(Client, id: id, secret: secret) do
      {:ok, client}
    else
      nil ->
        {:unauthorized, %{error: "invalid_client", error_description: "Invalid client_id or client_secret."}}
    end
  end

  def client(id: id, redirect_uri: redirect_uri) do
    with %Client{} = client <- Repo.get_by(Client, id: id, redirect_uri: redirect_uri) do
      {:ok, client}
    else
      nil ->
        {:unauthorized, %{error: "invalid_client", error_description: "Invalid client_id or redirect_uri."}}
    end
  end

  def user(id: id) do
    with %User{} = user <- Repo.get_by(User, id: id) do
      {:ok, user}
    else
      _ ->
        {:unauthorized, %{error: "invalid_resource_owner", error_description: "Invalid username or password."}}
    end
  end
  def user(email: username, password: password) do
    with %User{} = user <- Repo.get_by(User, email: username),
         true <- User.checkpw(password, user.password_hash) do
      {:ok, user}
    else
      _ ->
        {:unauthorized, %{error: "invalid_resource_owner", error_description: "Invalid username or password."}}
    end
  end
  def user(%User{} = user), do: {:ok, user}
  # TODO return more explicit error (that should be rescued in controller and not be sent to the client)
  def user(_), do: {:unauthorized, %{error: "invalid_resource_owner", error_description: "Resource owner is invalid."}}

  def code(value: value) do
    with %Token{} = token <- Repo.get_by(Token, type: "code", value: value) do
      {:ok, token}
    else
      nil ->
        {:unauthorized, %{error: "invalid_code", error_description: "Provided authorization code is incorrect."}}
    end
  end
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.ClientCredentialsRequest do
  import Boruta.Oauth.Authorization.Base

  alias Boruta.Oauth.ClientCredentialsRequest
  alias Boruta.Oauth.Token
  alias Boruta.Repo

  def token(%ClientCredentialsRequest{client_id: client_id, client_secret: client_secret}) do
    with {:ok, client} <- client(id: client_id, secret: client_secret) do
      Token.machine_changeset(%Token{}, %{
        client_id: client.id
      })
      |> Repo.insert()
    end
  end
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.ResourceOwnerPasswordCredentialsRequest do
  import Boruta.Oauth.Authorization.Base

  alias Boruta.Oauth.ResourceOwnerPasswordCredentialsRequest
  alias Boruta.Oauth.Token
  alias Boruta.Repo

  def token(%ResourceOwnerPasswordCredentialsRequest{
    client_id: client_id,
    client_secret: client_secret,
    username: username,
    password: password
  }) do

    with {:ok, client} <- client(id: client_id, secret: client_secret),
         {:ok, user} <- user(email: username, password: password) do
      Token.resource_owner_changeset(%Token{}, %{
        client_id: client.id,
        user_id: user.id
      })
      |> Repo.insert()
    end
  end
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.AuthorizationCodeRequest do
  import Boruta.Oauth.Authorization.Base

  alias Boruta.Oauth.AuthorizationCodeRequest
  alias Boruta.Oauth.Token
  alias Boruta.Repo

  def token(%AuthorizationCodeRequest{
    client_id: client_id,
    code: code,
    redirect_uri: redirect_uri,
  }) do
    with {:ok, client} <- client(id: client_id, redirect_uri: redirect_uri),
         {:ok, code} <- code(value: code),
         {:ok, user} <- user(id: code.user_id) do
      Token.resource_owner_changeset(%Token{}, %{
        client_id: client.id,
        user_id: user.id
      })
      |> Repo.insert()
    end
  end
end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.ImplicitRequest do
  import Boruta.Oauth.Authorization.Base

  alias Boruta.Oauth.ImplicitRequest
  alias Boruta.Oauth.Token
  alias Boruta.Repo

  def token(%ImplicitRequest{
    client_id: client_id,
    redirect_uri: redirect_uri,
    user: user
  }) do

    with {:ok, client} <- client(id: client_id, redirect_uri: redirect_uri),
         {:ok, user} <- user(user) do
      Token.resource_owner_changeset(%Token{user: user, client: client}, %{
        client_id: client.id,
        user_id: user.id
      })
      |> Repo.insert()
    end
  end

end

defimpl Boruta.Oauth.Authorization, for: Boruta.Oauth.CodeRequest do
  import Boruta.Oauth.Authorization.Base

  alias Boruta.Oauth.CodeRequest
  alias Boruta.Oauth.Token
  alias Boruta.Repo

  def token(%CodeRequest{
    client_id: client_id,
    redirect_uri: redirect_uri,
    user: user
  }) do

    with {:ok, client} <- client(id: client_id, redirect_uri: redirect_uri),
         {:ok, user} <- user(user) do
      Token.authorization_code_changeset(%Token{user: user, client: client}, %{
        client_id: client.id,
        user_id: user.id
      })
      |> Repo.insert()
    end
  end
end