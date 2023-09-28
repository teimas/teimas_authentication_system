module TeimasAuthenticationSystem
  module Keycloak
    module Base
      require 'rest-client'
      require 'json'
      require 'base64'
      require 'uri'

      KEYCLOAK_COMMON_HEADERS = {
        'Content-Type': 'application/x-www-form-urlencoded'
      }

      KEYCLOAK_JSON_COMMON_HEADERS = {
        'Content-Type': "application/json"
      }

      SCOPE = "openid"

      def self.admin_base_url(auth_server_url, realm)
        "#{auth_server_url}/admin/realms/#{realm}/"
      end

      def self.reset_password_url(auth_server_url, realm, client_id)
        "#{auth_server_url}/realms/#{realm}/login-actions/reset-credentials?client_id=#{client_id}"
      end

      def self.authentication_url(configuration, client_id, redirect_uri, response_type = 'code', params = {})
        params = params.merge({
          :response_type => response_type,
          :client_id => client_id,
          :redirect_uri => redirect_uri,
          :scope => SCOPE
        })

        p = URI.encode_www_form(params)
        "#{configuration['authorization_endpoint']}?#{p}"
      end

      def self.change_password_url(configuration, client_id, redirect_uri, response_type = 'code', params = {})
        params = params.merge({
          :response_type => response_type,
          :client_id => client_id,
          :redirect_uri => redirect_uri,
          :scope => SCOPE,
          :kc_action => "UPDATE_PASSWORD"
        })

        p = URI.encode_www_form(params)
        "#{configuration['authorization_endpoint']}?#{p}"
      end

      def self.openid_request(configuration, endpoint, payload)
        RestClient.post(configuration[endpoint], payload, KEYCLOAK_COMMON_HEADERS) do |response, _, _|
          case response.code
          when 200..399
            response.body
          else
            response.return!
          end
        end
      rescue RestClient::ExceptionWithResponse => err
        Rails.logger.error("TeimasAuthenticationSystem::Keycloak::Base::request Error #{err.message}: #{err.backtrace.join("\n")}")
        err.response
      end
    end
  end
end
