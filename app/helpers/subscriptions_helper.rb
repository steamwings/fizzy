module SubscriptionsHelper
  def currency(amount)
    number_to_currency(amount, precision: (amount % 1).zero? ? 0 : 2)
  end
end
