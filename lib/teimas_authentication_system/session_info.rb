module TeimasAuthenticationSystem
  class SessionInfo
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
    attr_accessor :expires_in

    #################################################################
    # CONSTRUCTOR
    #################################################################
    def initialize(data = {})
      self.access_token = data[:access_token]
      self.id_token = data[:id_token]
      self.refresh_token = data[:refresh_token]
      self.expires_in = data[:expires_in]
    end

  end
end