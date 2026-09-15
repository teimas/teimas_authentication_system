module TeimasAuthenticationSystem

  ###########################################################
  # EXCEPTIONS
  ###########################################################
  class TeimasAuthenticationSystemError < StandardError; end

  # Error devuelto por la API de Keycloak. Conserva el código de estado HTTP y el cuerpo de la respuesta para que el
  # llamante pueda distinguir, por ejemplo, un 409 (el username o el email ya están en uso) de un 500 (fallo del
  # servidor) y reaccionar de forma distinta.
  # Hereda de TeimasAuthenticationSystemError para no romper a quien ya captura ese error.
  class KeycloakApiError < TeimasAuthenticationSystemError
    attr_reader :http_code, :response_body

    def initialize(message, http_code = nil, response_body = nil)
      super(message)
      @http_code = http_code
      @response_body = response_body
    end
  end

  # Más de un usuario de Keycloak comparte el email buscado. Hay realms que permiten emails duplicados y en ese caso no
  # existe forma fiable de decidir cuál es el usuario correcto: elegir uno asociaría atributos, roles o grupos a la
  # persona equivocada, y crear otro añadiría un duplicado más. El conflicto tiene que resolverlo una persona.
  # Hereda de TeimasAuthenticationSystemError para no romper a quien ya captura ese error.
  class AmbiguousKeycloakUserError < TeimasAuthenticationSystemError
    attr_reader :email, :user_ids

    def initialize(message, email = nil, user_ids = [])
      super(message)
      @email = email
      @user_ids = user_ids
    end
  end

  # Keycloak respondió a la creación de un usuario con un 201 sin body y sin cabecera Location, así que no hay forma
  # de recuperar el usuario recién creado.
  # Hereda de TeimasAuthenticationSystemError para no romper a quien ya captura ese error.
  class KeycloakUserLocationMissingError < TeimasAuthenticationSystemError
    attr_reader :username, :email

    def initialize(message, username = nil, email = nil)
      super(message)
      @username = username
      @email = email
    end
  end

end