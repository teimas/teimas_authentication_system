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
  end
end
