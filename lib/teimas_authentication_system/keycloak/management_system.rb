module TeimasAuthenticationSystem::Keycloak::ManagementSystem
  require "teimas_authentication_system/keycloak/base"

  include TeimasAuthenticationSystem::Keycloak::Base

  # Crea el usuario en Keycloak o, si ya existe, lo añade al grupo asociado a la aplicación.
  # @param [String] :auth_server_url URL del servidor de keycloak
  # @param [String] :realm Nombre del realm de keycloak. Se obtiene de la cuenta a través del subdominio
  # @param [String] :client_id Id del client, el nombre de la aplicación como client en keycloak. Se obtiene de la cuenta a través del subdominio
  # @param [String] :client_secret Secret del client. Se obtiene de la cuenta a través del subdominio
  # @param [String] :keycloak_configuration Parámetros de configuración de OpenID obtenidos de Keycloak en base a la configuración de la cuenta
  # @param [String, Object>] user_data
  # @option config [String] username: Nombre del usuario en Keycloak.
  # @option config [String] email: Nombre del usuario en Keycloak.
  # @option config [String] first_name: Nombre del usuario
  # @option config [String] last_name: Apellido del usuario
  # @option config [String] password: Contraseña del usuario en Keycloak.
  # @option config [Array] realm_roles_names: Nombres de los roles del dominio asociados al usuario
  # @option config [Array] client_roles_names: Nombres de los roles del cliente asociados al usuario
  # @option config [Array] group_ids: Ids de los grupos asociados al usuario
  # @return Devuelve un hash con los datos del usuario en keycloak si el proceso ha finalizado correctamente.
  def self.create_or_update_user!(configuration, auth_server_url, realm, client_id, client_secret, user_data)
    ClientService.execute(configuration, client_id, client_secret) do |service|
      # Salvo que se indique, find_users buscara de forma estricta por username
      user = find_users(auth_server_url, realm, service, { :username => user_data[:username] }).try(:[], 0)
      user_creation_params = {
        username: user_data[:username],
        email: user_data[:email],
        firstName: user_data[:first_name],
        lastName: user_data[:last_name],
        enabled: true
      }
      user_creation_params[:attributes] = user_data[:attributes] if user_data[:attributes].present?

      if user.present?
        if user_data[:attributes].present?
          user["attributes"] = (user["attributes"] || {}).merge(user_data[:attributes])
          user = update_user!(auth_server_url, realm, service, user["id"], user)
        end
      else
        user = create_user!(auth_server_url, realm, service, user_creation_params)

        if user_data[:password].present?
          credential_representation = {
            type: "password",
            temporary: true,
            value: user_data[:password]
          }

          reset_password!(auth_server_url, realm, service, user["id"], credential_representation)
        end
      end

      if user_data[:client_roles_names].present?
        client = find_clients(auth_server_url, realm, service, { first: 10 }).try(:[], 0)
        if client.present?
          client_roles = user_data[:client_roles_names].map do |role_name|
            client_role = find_client_role(auth_server_url, realm, service, client[:id], role_name)
            raise "Cannot find client_role #{role_name}" if client_role.blank?
          end
          if client_roles.present?
            add_client_roles_to_user!(auth_server_url, realm, service, user["id"], client["id"], client_roles)
          end
        else
          raise "Cannot find client #{client_id}"
        end
      end

      if user_data[:realm_roles_names].present?
        realm_roles = user_data[:realm_roles_names].map do |role_name|
          realm_role = find_realm_role(auth_server_url, realm, service, role_name)
          raise "Cannot find realm_role #{role_name}" if realm_role.blank?
        end

        if realm_roles.present?
          add_realm_roles_to_user!(auth_server_url, realm, service, user["id"], realm_roles)
        end
      end

      if user_data[:group_ids].present?
        user_data[:group_ids].each do |group_id|
          group = find_group(auth_server_url, realm, service, group_id)
          if group.present?
            add_group_to_user!(auth_server_url, realm, service, user["id"], group["id"])
          else
            raise "Cannot find group #{group_id}"
          end
        end
      end

      user
    end
  end

  private

  def self.update_user!(auth_server_url, realm, service, user_id, user_data)
    headers = KEYCLOAK_JSON_COMMON_HEADERS.merge({'Authorization' => "Bearer #{service.access_token}"})
    url = TeimasAuthenticationSystem::Keycloak::Base.admin_base_url(auth_server_url, realm) + "users/#{user_id}"

    RestClient.put(url, JSON.generate(user_data), headers) do |response, request, result|
      response.return!
      user_data
    end
  end

  def self.find_users(auth_server_url, realm, service, search_params, imprecise_search = false)
    headers = KEYCLOAK_COMMON_HEADERS.merge({'Authorization' => "Bearer #{service.access_token}"})
    url = TeimasAuthenticationSystem::Keycloak::Base.admin_base_url(auth_server_url, realm) + "users/"

    search_params[:exact] = true unless imprecise_search

    if search_params.present?
      url = url + '?' + URI.encode_www_form(search_params)
    end

    RestClient.get(url, headers) do |response, request, result|
      response = response.return!
      response.body.present? ? JSON.parse(response.body) : nil
    end
  rescue StandardError => e
    Rails.logger.error("TeimasAuthenticationSystem::Keycloak::ManagementSystem: Error buscando usuarios #{e.message}: #{e.backtrace.join("\n")}")
    nil
  end

  def self.create_user!(auth_server_url, realm, service, user_data)
    headers = KEYCLOAK_JSON_COMMON_HEADERS.merge({'Authorization' => "Bearer #{service.access_token}"})
    url = TeimasAuthenticationSystem::Keycloak::Base.admin_base_url(auth_server_url, realm) + "users/"

    RestClient.post(url, JSON.generate(user_data), headers) do |response, request, result|
      response = response.return!
      if response.body.present?
        JSON.parse(response.body)
      else
        find_users(auth_server_url, realm, service, { username: user_data[:username] })[0]
      end
    end
  end

  def self.reset_password!(auth_server_url, realm, service, user_id, credential_data)
    headers = KEYCLOAK_JSON_COMMON_HEADERS.merge({'Authorization' => "Bearer #{service.access_token}"})
    url = TeimasAuthenticationSystem::Keycloak::Base.admin_base_url(auth_server_url, realm) + "users/#{user_id}/reset-password/"
    RestClient.put(url, JSON.generate(credential_data), headers) do |response, request, result|
      response.return!
      true
    end
  end

  def self.find_clients(auth_server_url, realm, service, search_params)
    headers = KEYCLOAK_COMMON_HEADERS.merge({'Authorization' => "Bearer #{service.access_token}"})
    url = TeimasAuthenticationSystem::Keycloak::Base.admin_base_url(auth_server_url, realm) + "clients"

    if search_params.present?
      url = url + '?' + URI.encode_www_form(search_params)
    end

    RestClient.get(url, headers) do |response, request, result|
      response = response.return!
      response.body.present? ? JSON.parse(response.body) : nil
    end
  rescue StandardError => e
    Rails.logger.error("TeimasAuthenticationSystem::Keycloak::ManagementSystem: Error buscando clientes #{e.message}: #{e.backtrace.join("\n")}")
    nil
  end

  def self.find_client_role(auth_server_url, realm, service, client_id, role_name)
    headers = KEYCLOAK_COMMON_HEADERS.merge({'Authorization' => "Bearer #{service.access_token}"})
    url = TeimasAuthenticationSystem::Keycloak::Base.admin_base_url(auth_server_url, realm) + "clients/#{client_id}/roles/#{role_name}"

    RestClient.get(url, headers) do |response, request, result|
      response = response.return!
      response.body.present? ? JSON.parse(response.body): nil
    end
  rescue StandardError => e
    Rails.logger.error("TeimasAuthenticationSystem::Keycloak::ManagementSystem: Error buscando roles en el cliente #{e.message}: #{e.backtrace.join("\n")}")
    nil
  end

  def self.add_client_roles_to_user!(auth_server_url, realm, service, user_id, client_id, roles)
    headers = KEYCLOAK_JSON_COMMON_HEADERS.merge({'Authorization' => "Bearer #{service.access_token}"})
    url = TeimasAuthenticationSystem::Keycloak::Base.admin_base_url(auth_server_url, realm) + "users/#{user_id}/role-mappings/clients/#{client_id}"

    RestClient.post(url, JSON.generate(roles), headers) do |response, request, result|
      response.return!
      true
    end
  end

  def self.find_group(auth_server_url, realm, service, group_id)
    headers = KEYCLOAK_COMMON_HEADERS.merge({'Authorization' => "Bearer #{service.access_token}"})
    url = TeimasAuthenticationSystem::Keycloak::Base.admin_base_url(auth_server_url, realm) + "groups/#{group_id}"

    RestClient.get(url, headers) do |response, request, result|
      response = response.return!
      response.body.present? ? JSON.parse(response.body): nil
    end
  rescue StandardError => e
    Rails.logger.error("TeimasAuthenticationSystem::Keycloak::ManagementSystem: Error buscando grupos #{e.message}: #{e.backtrace.join("\n")}")
    nil
  end

  def self.add_group_to_user!(auth_server_url, realm, service, user_id, group_id)
    headers = KEYCLOAK_JSON_COMMON_HEADERS.merge({'Authorization' => "Bearer #{service.access_token}"})
    url = TeimasAuthenticationSystem::Keycloak::Base.admin_base_url(auth_server_url, realm) + "users/#{user_id}/groups/#{group_id}"
    RestClient.put(url, {}, headers) do |response, request, result|
      response.return!
      true
    end
  end

  def self.find_realm_role(auth_server_url, realm, service, role_name)
    headers = KEYCLOAK_COMMON_HEADERS.merge({'Authorization' => "Bearer #{service.access_token}"})
    url = TeimasAuthenticationSystem::Keycloak::Base.admin_base_url(auth_server_url, realm) + "roles/#{role_name}"
    RestClient.get(url, headers) do |response, request, result|
      response = response.return!
      response.body.present? ? JSON.parse(response.body) : nil
    end
  rescue StandardError => e
    Rails.logger.error("TeimasAuthenticationSystem::Keycloak::ManagementSystem: Error buscando roles #{e.message}: #{e.backtrace.join("\n")}")
    nil
  end

  def self.add_realm_roles_to_user!(auth_server_url, realm, service, user_id, roles)
    headers = KEYCLOAK_JSON_COMMON_HEADERS.merge({'Authorization' => "Bearer #{service.access_token}"})
    url = TeimasAuthenticationSystem::Keycloak::Base.admin_base_url(auth_server_url, realm) + "users/#{user_id}/role-mappings/realm"
    RestClient.post(url, JSON.generate(roles), headers) do |response, request, result|
      response.return!
      true
    end
  end

  # Cliente de conexión autogestionado que devuelve el servicio para acceder a la parte de gestión de Keycload y se
  # cierra automáticamente después de finalizar la comunicación con Keycloak
  class ClientService
    include TeimasAuthenticationSystem::Keycloak::Base

    attr_accessor :client_id, :client_secret, :configuration, :session_token

    def self.execute(configuration, client_id, client_secret, &block)
      service = ClientService.new(configuration, client_id, client_secret)
      service.open_connection!
      block.call(service)
    ensure
      service.close! if service.present?
    end

    def initialize(configuration, client_id, client_secret)
      self.client_id = client_id
      self.client_secret = client_secret
      self.configuration = configuration
    end

    def open_connection!
      payload = {
        'client_id' => client_id,
        'client_secret' => client_secret,
        'grant_type' => 'client_credentials',
        'scope' => TeimasAuthenticationSystem::Keycloak::ManagementSystem::SCOPE
      }

      result = TeimasAuthenticationSystem::Keycloak::Base.openid_request(configuration, 'token_endpoint', payload)
      self.session_token = JSON.parse(result)
    rescue RestClient::ExceptionWithResponse => err
      Rails.logger.error("TeimasAuthenticationSystem::Keycloak::ManagementSystem::ClientService Error inicializando cliente #{err.message}: #{err.backtrace.join("\n")}")
      raise(TeimasAuthenticationSystem::TeimasAuthenticationSystemError, "Error al inicializar conexión con TeimasID. Por favor revise los parametros de configuración de KeyCloak")
    end

    def access_token
      session_token["access_token"] if session_token.present?
    end

    def close!
      if session_token
        payload = {
          'client_id' => client_id,
          'client_secret' => client_secret,
        }
        payload['refresh_token'] = session_token["refresh_token"] if session_token["refresh_token"].present?

        TeimasAuthenticationSystem::Keycloak::Base.openid_request(configuration, 'end_session_endpoint', payload)
      end
    rescue RestClient::ExceptionWithResponse => err
      Rails.logger.error("TeimasAuthenticationSystem::Keycloak::ManagementSystem::ClientService Error cerrando session en cliente #{err.message}: #{err.backtrace.join("\n")}")
    end
  end

end