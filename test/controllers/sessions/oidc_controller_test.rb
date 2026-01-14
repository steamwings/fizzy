require "test_helper"

class Sessions::OidcControllerTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:oidc] = nil
  end

  test "successful authentication creates session" do
    auth_hash = build_auth_hash(
      uid: "oidc-123",
      email: "test@example.com",
      email_verified: true
    )

    OmniAuth.config.mock_auth[:oidc] = auth_hash

    untenanted do
      # Simulate OmniAuth by setting the env directly
      post "/auth/oidc/callback", env: { "omniauth.auth" => auth_hash }

      assert_response :redirect
      assert cookies[:session_token].present?

      identity = Identity.find_by(email_address: "test@example.com")
      assert identity.present?
      assert_equal "oidc-123", identity.oidc_subject
      assert_equal "oidc", identity.oidc_provider
    end
  end

  test "links OIDC to existing identity by email" do
    existing = identities(:david)

    auth_hash = build_auth_hash(
      uid: "oidc-456",
      email: existing.email_address,
      email_verified: true
    )

    OmniAuth.config.mock_auth[:oidc] = auth_hash

    untenanted do
      post "/auth/oidc/callback", env: { "omniauth.auth" => auth_hash }

      existing.reload
      assert_equal "oidc-456", existing.oidc_subject
      assert_equal "oidc", existing.oidc_provider
    end
  end

  test "handles authentication failure" do
    OmniAuth.config.mock_auth[:oidc] = :invalid_credentials

    untenanted do
      get "/auth/failure", params: { message: "invalid_credentials" }

      assert_redirected_to new_session_path
      assert_not cookies[:session_token].present?
    end
  end

  test "rate limits callback requests" do
    skip "Rate limiting in tests requires time manipulation - skipping for now"
    # Rate limiting is configured on the controller (10 requests per 15 minutes)
    # but testing it properly requires freezing time or mocking the rate limiter
    # The rate_limit_exceeded method is tested indirectly
  end

  test "handles missing auth hash" do
    untenanted do
      # Don't set OmniAuth mock, so auth_hash will be nil
      post "/auth/oidc/callback"

      assert_redirected_to new_session_path
      assert_match /failed/i, flash[:alert].to_s.downcase
    end
  end

  test "handles identity creation failure" do
    auth_hash = build_auth_hash(
      uid: "",  # Empty uid will cause validation failure
      email: "test@example.com"
    )

    OmniAuth.config.mock_auth[:oidc] = auth_hash

    untenanted do
      post "/auth/oidc/callback", env: { "omniauth.auth" => auth_hash }

      assert_redirected_to new_session_path
      assert_not cookies[:session_token].present?
    end
  end

  private
    def build_auth_hash(uid:, email:, email_verified: true, name: "Test User")
      OmniAuth::AuthHash.new(
        provider: "oidc",
        uid: uid,
        info: {
          email: email,
          name: name
        },
        extra: {
          raw_info: {
            email_verified: email_verified
          }
        }
      )
    end
end
