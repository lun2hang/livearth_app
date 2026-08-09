/// Stripe 状态及响应数据模型

class StripeStatusResponse {
  final bool hasCustomerId;
  final bool hasConnectAccount;
  final bool stripeConnectOnboarded;
  final String? stripeCustomerId;
  final String? stripeConnectId;

  StripeStatusResponse({
    required this.hasCustomerId,
    required this.hasConnectAccount,
    required this.stripeConnectOnboarded,
    this.stripeCustomerId,
    this.stripeConnectId,
  });

  factory StripeStatusResponse.fromJson(Map<String, dynamic> json) {
    return StripeStatusResponse(
      hasCustomerId: json['has_customer_id'] ?? false,
      hasConnectAccount: json['has_connect_account'] ?? false,
      stripeConnectOnboarded: json['stripe_connect_onboarded'] ?? false,
      stripeCustomerId: json['stripe_customer_id'],
      stripeConnectId: json['stripe_connect_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_customer_id': hasCustomerId,
      'has_connect_account': hasConnectAccount,
      'stripe_connect_onboarded': stripeConnectOnboarded,
      'stripe_customer_id': stripeCustomerId,
      'stripe_connect_id': stripeConnectId,
    };
  }
}

class SetupIntentResponse {
  final String clientSecret;
  final String customerId;

  SetupIntentResponse({
    required this.clientSecret,
    required this.customerId,
  });

  factory SetupIntentResponse.fromJson(Map<String, dynamic> json) {
    return SetupIntentResponse(
      clientSecret: json['client_secret'] ?? '',
      customerId: json['customer_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_secret': clientSecret,
      'customer_id': customerId,
    };
  }
}

class ConnectAccountLinkResponse {
  final String url;
  final String accountId;

  ConnectAccountLinkResponse({
    required this.url,
    required this.accountId,
  });

  factory ConnectAccountLinkResponse.fromJson(Map<String, dynamic> json) {
    return ConnectAccountLinkResponse(
      url: json['url'] ?? '',
      accountId: json['account_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'account_id': accountId,
    };
  }
}
