module TeimasAuthenticationSystem::Keycloak::Users
  require "teimas_authentication_system/keycloak/base"

  include TeimasAuthenticationSystem::Keycloak::Base

  def self.find_user_token_by_code(configuration, client_id, client_secret, code, redirect_uri)
    payload = {
      'client_id': client_id,
      'client_secret': client_secret,
      'grant_type' => 'authorization_code',
      'scope' => SCOPE,
      'redirect_uri' => redirect_uri,
      'code' => code
    }

    TeimasAuthenticationSystem::Keycloak::Base.openid_request(configuration, 'token_endpoint', payload)
  end

  def self.find_user_token_by_refresh_token(configuration, client_id, client_secret, refresh_token)
    payload = {
      'client_id' => client_id,
      'client_secret' => client_secret,
      'scope' => SCOPE,
      'grant_type' => 'refresh_token',
      'refresh_token' => refresh_token
    }

    TeimasAuthenticationSystem::Keycloak::Base.openid_request(configuration, 'token_endpoint', payload)
  end

  def self.find_user_info_by_access_token(configuration, access_token)
    payload = { 'access_token' => access_token }

    TeimasAuthenticationSystem::Keycloak::Base.openid_request(configuration, 'userinfo_endpoint', payload)
  end


  def self.users_logout(configuration, client_id, client_secret, id_token, refresh_token = '', redirect_uri = '')
    if id_token.present?
      payload = {
        'client_id' => client_id,
        'client_secret' => client_secret,
        'id_token_hint'=> id_token
      }
      payload['refresh_token'] = refresh_token if refresh_token.present?
      payload['redirect_uri'] = redirect_uri if redirect_uri.present?

      TeimasAuthenticationSystem::Keycloak::Base.openid_request(configuration, 'end_session_endpoint', payload)
      true
    else
      true
    end
  end

end
