module TeimasAuthenticationSystem
  class UserInfo

    # ATRIBUTOS DEL USUARIO
    # JSON con la información de la sesión. De él se extraen los siguientes atributos.
    attr_accessor :info
    # Email del usuario utilizado para el inicio de sesión
    attr_accessor :email
    # Roles asignados al usuario en keycloak
    attr_accessor :roles
    # Identificador del usuario de keycloak
    attr_accessor :uuid
    # Sesión de Keycloak
    attr_accessor :session_info


    delegate :id_token, :refresh_token, :expires_in, :to => :session_info, :allow_nil => true, :prefix => :session

    #################################################################
    # CONSTRUCTOR
    #################################################################
    def initialize(data = {})
      self.info = data[:info]
      self.email = data[:email]
      self.roles = data[:roles]
      self.uuid = data[:uuid]
      self.session_info = data[:session_info]
    end

  end
end