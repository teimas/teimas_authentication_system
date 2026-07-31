# frozen_string_literal: true

require "spec_helper"

RSpec.describe TeimasAuthenticationSystem::Client do
  describe "#create_or_update_user!" do
    subject(:create_or_update_user!) { client.create_or_update_user!("login@example.com", user_data) }

    let(:client) do
      described_class.allocate.tap do |instance|
        instance.instance_variable_set(:@configuration, :configuration)
        instance.instance_variable_set(:@auth_server_url, "https://keycloak.example.com")
        instance.instance_variable_set(:@realm, "realm")
        instance.instance_variable_set(:@client_id, "client-id")
        instance.instance_variable_set(:@client_secret, "client-secret")
      end
    end

    let(:user_data) do
      {
        email: "user@example.com",
        password: "secret",
        attributes: { locale: :es },
        zero_account: "ignored"
      }
    end

    it "forwards only explicit attributes" do
      expect(TeimasAuthenticationSystem::Keycloak::ManagementSystem).to receive(:create_or_update_user!).with(
        :configuration,
        "https://keycloak.example.com",
        "realm",
        "client-id",
        "client-secret",
        {
          username: "login@example.com",
          email: "user@example.com",
          password: "secret",
          attributes: { "locale" => ["es"] }
        }
      ).and_return(true)

      expect(create_or_update_user!).to eq(true)
    end

    it "raises a KeycloakApiError preserving the HTTP status code" do
      conflict_response = Struct.new(:code, :body).new(409, '{"errorMessage":"User exists with same email"}')

      stub_const("Rails", double(logger: double(error: nil)))
      allow(TeimasAuthenticationSystem::Keycloak::ManagementSystem).to receive(:create_or_update_user!)
        .and_raise(RestClient::Conflict.new(conflict_response, 409))

      expect { create_or_update_user! }.to raise_error(TeimasAuthenticationSystem::KeycloakApiError) do |error|
        expect(error).to be_a(TeimasAuthenticationSystem::TeimasAuthenticationSystemError)
        expect(error.http_code).to eq(409)
        expect(error.response_body).to eq('{"errorMessage":"User exists with same email"}')
        expect(error.message).to eq("Error al crear usuario en TeimasID")
      end
    end

    it "lets ambiguous user errors through unchanged" do
      ambiguous_error = TeimasAuthenticationSystem::AmbiguousKeycloakUserError.new(
        "Dos usuarios comparten el email user@example.com"
      )
      allow(TeimasAuthenticationSystem::Keycloak::ManagementSystem).to receive(:create_or_update_user!)
        .and_raise(ambiguous_error)

      expect { create_or_update_user! }.to raise_error(ambiguous_error)
    end
  end
end
