import { UserManager } from 'oidc-client-ts';

export const auth = new UserManager({
  authority: 'http://127.0.0.1:9000',
  client_id: 'truenorth119-web',
  redirect_uri: 'http://127.0.0.1:5173/callback',
  post_logout_redirect_uri: 'http://127.0.0.1:5173/',
  response_type: 'code',
  scope: 'openid profile api.read',
  automaticSilentRenew: false,
  loadUserInfo: false,
  monitorSession: false,
});
