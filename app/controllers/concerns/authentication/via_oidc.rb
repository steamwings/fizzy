module Authentication::ViaOidc
  extend ActiveSupport::Concern

  class_methods do
    def oidc_enabled?
      ENV["OIDC_ISSUER"].present?
    end

    def oidc_required?
      ENV["OIDC_REQUIRED"] == "true"
    end
  end

  delegate :oidc_enabled?, :oidc_required?, to: :class
end
