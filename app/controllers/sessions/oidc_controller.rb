class Sessions::OidcController < ApplicationController
  disallow_account_scope
  require_unauthenticated_access
  rate_limit to: 10, within: 15.minutes, only: :create, with: :rate_limit_exceeded
  skip_forgery_protection only: :create

  layout "public"

  def create
    auth_hash = request.env["omniauth.auth"]

    if auth_hash.present?
      authenticate_with_oidc(auth_hash)
    else
      authentication_failed("Authentication data not found")
    end
  rescue => e
    Rails.error.report(e, severity: :error)
    authentication_failed("Authentication failed")
  end

  def failure
    error_type = params[:message] || "unknown_error"
    authentication_failed("OIDC authentication failed: #{error_type}")
  end

  private
    def authenticate_with_oidc(auth_hash)
      identity = Identity.find_or_create_from_oidc(auth_hash)

      if identity.persisted?
        start_new_session_for identity
        redirect_to after_authentication_url
      else
        authentication_failed("Failed to create or find identity")
      end
    end

    def authentication_failed(message)
      Rails.logger.warn "OIDC authentication failed: #{message}"

      respond_to do |format|
        format.html { redirect_to new_session_path, alert: "Authentication failed. Please try again." }
        format.json { render json: { message: message }, status: :unauthorized }
      end
    end

    def rate_limit_exceeded
      respond_to do |format|
        format.html { redirect_to new_session_path, alert: "Too many attempts. Try again in 15 minutes." }
        format.json { render json: { message: "Rate limit exceeded" }, status: :too_many_requests }
      end
    end
end
