/* INACTIVE until ItamaRos Hub provides a verified OIDC issuer, client ID and
   server-side one-time ticket exchange. This is PUBLIC configuration, not a secret. */
window.ITAMAR_HUB_AUTH = Object.freeze({
  enabled: false,
  callbackPath: "/hub/callback.html",
  exchangeEndpoint: "/api/hub/exchange",
  approvedIssuer: "",
  clientId: ""
});
