module TeimasAuthenticationSystem::Keycloak::Config
  require "teimas_authentication_system/keycloak/base"
  include TeimasAuthenticationSystem::Keycloak::Base

  def self.get_openid_configuration(auth_server_url, realm)
    config_url = "#{auth_server_url}/realms/#{realm}/.well-known/openid-configuration"
    response = RestClient.get config_url
    case response.code
    when 200..299
      JSON.parse(response.body)
    when 300..399
      raise "Error al cargar la configuración de keycloak"
    else
      response.return!
    end
  rescue RestClient::ExceptionWithResponse => err
    Rails.logger.error("TeimasAuthenticationSystem::Keycloak::ManagementSystem::Config Error inicializando configuración #{err.message}: #{err.backtrace.join("\n")}")
    raise err
  end
end
