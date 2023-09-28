module TeimasAuthenticationSystem
  class UserInfo

    #################################################################
    # ATRIBUTOS
    #################################################################
    # ATRIBUTOS DEL USUARIO
    # JSON con la información de la sesión. De él se extraen los siguientes atributos.
    attr_accessor :info
    # Email del usuario utilizado para el inicio de sesión
    attr_accessor :email
    # Roles asignados al usuario en keycloak
    attr_accessor :roles
    # Identificador del usuario de keycloak
    attr_accessor :uuid

    #################################################################
    # CONSTRUCTOR
    #################################################################
    def initialize(data = {})
      self.info = data[:info]
      self.email = data[:email]
      self.roles = data[:roles]
      self.uuid = data[:uuid]
    end

  end
end
