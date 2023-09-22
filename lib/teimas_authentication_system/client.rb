module TeimasAuthenticationSystem

  class Client
    require "teimas_authentication_system/keycloak/base"
    require "teimas_authentication_system/keycloak/config"
    require "teimas_authentication_system/keycloak/management_system"
    require "teimas_authentication_system/keycloak/users"
    require "teimas_authentication_system/exceptions"
    require "teimas_authentication_system/session_info"
    require "teimas_authentication_system/user_info"

    #################################################################
    # CONSTRUCTOR
    #################################################################
    # @param [Hash<Symbol, Object>] config
    # @option config [String] :auth_server_url URL del servidor de keycloak
    # @option config [String] :client_id Id del client, el nombre de la aplicación como client en keycloak. Se obtiene de la cuenta a través del subdominio
    # @option config [String] :client_secret Secret del client. Se obtiene de la cuenta a través del subdominio
    # @option config [String] :realm Nombre del realm de keycloak. Se obtiene de la cuenta a través del subdominio
    # @return [TeimasAuthenticationSystem::Client] Cliente del sistema de autenticación con la configuración indicada
    def initialize(config = {})
      if config.present? && config[:auth_server_url].present? && config[:client_id] && config[:client_secret] && config[:realm]
        # Se configura el cliente con la configuración indicada
        @auth_server_url = config[:auth_server_url]
        @client_id = config[:client_id]
        @client_secret = config[:client_secret]
        @realm = config[:realm]
        # Se obtiene la configuración de OpenID de Keycloak en base a los parámetros de configuración indicados en el paso anterior
        @configuration = TeimasAuthenticationSystem::Client.configuration(@auth_server_url, @realm)
      else
        raise(TeimasAuthenticationSystemError, "Es necesario indicar los siguientes parámetros de configuración de keycloak(auth_server_url, client_id, client_secret, realm)")
      end
    end

    #################################################################
    # MÉTODOS DE CLASE
    #################################################################
    def self.configuration(auth_server_url, realm)
      @@configuration ||= {}
      @@configuration["#{realm}_#{auth_server_url}"] ||= TeimasAuthenticationSystem::Keycloak::Config.get_openid_configuration(
        auth_server_url,
        realm
      )
    end

    #################################################################
    # MÉTODOS DE INSTANCIA
    #################################################################

    # Devuelve la URL de login de Keycloak, indicando la dirección de respuesta y el tipo de respuesta que se
    # utilizará para la autenticación con OpenID
    def authentication_url(redirect_uri, login_hint = nil)
      begin
        TeimasAuthenticationSystem::Keycloak::Base.authentication_url(
          @configuration,
          @client_id,
          redirect_uri,
          'code',
          {
            :login_hint => login_hint
          })
      rescue StandardError => exception
        Rails.logger.error("TeimasAuthenticationSystem::Client.authentication_url possible keycloak configuration error (url, realm, etc.), exception:#{exception.class} (#{exception.message})")
        nil
      end
    end

    # Devuelve la URL de cambio de contraseña de keycloak
    def change_password_url(redirect_uri, login_hint = nil)
      begin
        TeimasAuthenticationSystem::Keycloak::Base.change_password_url(@configuration, @client_id, redirect_uri, 'code', {:login_hint => login_hint})
      rescue StandardError => exception
        Rails.logger.error("TeimasAuthenticationSystem::Client.change_password_url possible keycloak configuration error (url, realm, etc.), exception:#{exception.class} (#{exception.message})")
        nil
      end
    end

    # Crea el usuario en Keycloak o, si ya existe, lo añade al grupo asociado a la aplicación.
    # @param [String] :login Correo electrónico del usuario
    # @param [Hash<Symbol, Object>] user_data
    # @option user_data [String | null] :username Nombre del usuario en Keycloak
    # @option user_data [String] :email Email del usuario en keycloak
    # @option user_data [String] :password Contraseña del usuario en keycloak
    # Nota: tanto username como email deben ser únicos para el usuario, y pueden usarse indistintamente
    # para autenticarse junto con la contraseña en Keycloak
    # @return [Boolean] Devuelve true si el proceso ha finalizado correctamente
    def create_or_update_user!(login, user_data)
      result = TeimasAuthenticationSystem::Keycloak::ManagementSystem.create_or_update_user!(
        @configuration,
        @auth_server_url,
        @realm,
        @client_id,
        @client_secret,
        {
          username: login,
          email: user_data[:email],
          password: user_data[:password]
        }
      )
      result
    rescue Exception => e
      case e
      when TeimasAuthenticationSystemError
        raise e
      else
        Rails.logger.error("TeimasAuthenticationSystem::Client Error al crear crear/actualizar #{login}. exception:#{e.class} (#{e.message}) #{e.backtrace.join("\n")}")
        raise(TeimasAuthenticationSystemError, "Error al crear usuario en TeimasID")
      end
    end

    # Loggea al usuario en keycloak y guarda en el cliente
    # @return [TeimasAuthenticationSystem::UserInfo | nil] Devuelve la información del usuario o nil si no se ha podido realizar el login
    def login!(redirect_uri, session_code)
      if redirect_uri.blank? || session_code.blank?
        raise(TeimasAuthenticationSystemError, "Es necesario indicar un codigo de sesión y una URL de redirección")
      end

      session = session_info(session_code, redirect_uri)
      if session.blank?
        raise(TeimasAuthenticationSystemError, "Código de sesión invalido, no se encuentra keycloak_session_info")
      end

      user_info = user_info(session.access_token)
      if user_info.present?
        user_info.session_info = session
        user_info
      else
        raise(TeimasAuthenticationSystemError, "Código de sesión invalido")
      end
    end

    # Refresca la sesión actual utilizando el token de refresco ofrecido en la sesión anterior.
    # @return Devuelve la información de la sesión (o nil si ha fallado el refresco):
    # - access_token: Token de sesión
    # - expires_in: Tiempo de expiración del token de sesión en segundos
    # - refresh_expires_in: Tiempo de expiración del token de refresco de la sesión en segundos
    # - refresh_token: Token de refresco de la sesión
    # - token_type: Tipo del token, normalmente Bearer
    # - not-before-policy: Configuración que especifica si el hecho de emitir un token hace inválidos los tokens anteriores.
    # - session_state: Id de la sesión de Keycloak
    # - scope: Roles asociados al usuario que ha generado el token
    def refresh_session(refresh_token)
      response = TeimasAuthenticationSystem::Keycloak::Users.find_user_token_by_refresh_token(@configuration, @client_id, @client_secret, refresh_token)
      if response.present? && (refresh_session_response = JSON.parse(response)) && refresh_session_response["access_token"].present?
        TeimasAuthenticationSystem::SessionInfo.new({
          :id_token => refresh_session_response["id_token"],
          :refresh_token => refresh_session_response["refresh_token"],
          :expires_in => DateTime.now + refresh_session_response["expires_in"].seconds
        })
      else
        nil
      end
    rescue Exception => exception
      Rails.logger.error("TeimasAuthenticationSystem::Client.refresh_session refresh_token:'#{refresh_token}', exception:#{exception.class} (#{exception.message})")
      nil
    end

    # Desloguea el usuario.
    # @return Devuelve true o false dependiendo de si se ha podido realizar el Logout
    def logout(token_id, refresh_token = '', redirect_url = '')
      TeimasAuthenticationSystem::Keycloak::Users.users_logout(@configuration, @client_id, @client_secret, token_id, refresh_token, redirect_url)
    end

    # Devuelve si el usuario está autorizado en la aplicación actual comprobando
    # si el mismo está incluido en el grupo de Keycloak asociado a la aplicación
    # LEGACY: Actualmente KeyCloak no autoriza por aplicación.
    # def is_user_authorized_in_app?
    #   user_roles.present? && user_roles.include?("#{APP_ROLE_NAME}")
    # end

    #################################################################
    # MÉTODOS PRIVADOS
    #################################################################
    private

    # Devuelve la información de la sesión asociada a un usuario que se registró correctamente en Keycloak.
    # @return [Hash<String, Object>] Devuelve la información de la sesión (o nil si ha fallado):
    # - access_token: Token de sesión
    # - expires_in: Tiempo de expiración del token de sesión en segundos
    # - refresh_expires_in: Tiempo de expiración del token de refresco de la sesión en segundos
    # - refresh_token: Token de refresco de la sesión
    # - token_type: Tipo del token, normalmente Bearer
    # - not-before-policy: Configuración que especifica si el hecho de emitir un token hace inválidos los tokens anteriores.
    # - session_state: Id de la sesión de Keycloak
    # - scope: Roles asociados al usuario que ha generado el token
    def session_info(code, redirect_uri)
      response = TeimasAuthenticationSystem::Keycloak::Users.find_user_token_by_code(@configuration, @client_id, @client_secret, code, redirect_uri)
      if response.present? && (parsed_session_info = JSON.parse(response))
        TeimasAuthenticationSystem::SessionInfo.new({
          :access_token => parsed_session_info["access_token"],
          :id_token => parsed_session_info["id_token"],
          :refresh_token => parsed_session_info["refresh_token"],
          :expires_in => DateTime.now + parsed_session_info["expires_in"].seconds
        })
      end
    rescue Exception => exception
      Rails.logger.error("TeimasAuthenticationSystem::Client.session_info code:'#{code}', exception:#{exception.class} (#{exception.message})")
      nil
    end

    def user_info(access_token)
      response = TeimasAuthenticationSystem::Keycloak::Users.find_user_info_by_access_token(@configuration, access_token)
      if response.present? && (parsed_user_info = JSON.parse(response))
        TeimasAuthenticationSystem::UserInfo.new(
          :info => parsed_result,
          :email => parsed_result["email"],
          :roles => parsed_result["roles"],
          :uuid => parsed_result["sub"]
        )
      end
    rescue Exception => exception
      Rails.logger.error("TeimasAuthenticationSystem::Client.user_info exception:#{exception.class} (#{exception.message})")
      nil
    end
  end

end
