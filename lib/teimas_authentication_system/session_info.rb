module TeimasAuthenticationSystem
  class SessionInfo
    require "jwt"
    #################################################################
    # ATRIBUTOS
    #################################################################
    # ATRIBUTOS DE LA SESIÓN DE KEYCLOAK
    # Token de la sesión
    attr_accessor :access_token
    # Itentificador de la sesión asociada al usuario en keycloak
    attr_accessor :id_token
    # Token de refresco de la sesión. Permite obtener un nuevo token de sesión.
    attr_accessor :refresh_token
    # Tiempo de expiración del token de sesión en segundos
    attr_accessor :expires_at
    # Datos de usuario de Keycloak asociado
    attr_accessor :user_info

    #################################################################
    # COMPORTAMIENTO DECLARATIVO
    #################################################################
    delegate :email, :uuid, :to => :user_info, :allow_nil => true, :prefix => :user

    #################################################################
    # CONSTRUCTOR
    #################################################################
    def initialize(data = {})
      self.access_token = data[:access_token]
      self.id_token = data[:id_token]
      self.refresh_token = data[:refresh_token]
      self.expires_at = data[:expires_at]
      # En caso de que exista id_token, intentamos hacer un decode y guardar los datos relativos
      #   al usuario.
      if id_token.present?
        decoded_id_token_payload, decoded_id_token_header = JWT.decode(id_token, nil, false)
        self.user_info = TeimasAuthenticationSystem::UserInfo.new(
          :info => {},
          :email => decoded_id_token_payload["email"],
          :uuid => decoded_id_token_payload["sub"]
        )
      end
    end

  end
end
