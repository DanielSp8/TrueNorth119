import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { auth } from './auth';
import './style.css';

function App() {
  const [user, setUser] = useState(null);
  const [result, setResult] = useState('');
  const [error, setError] = useState('');
  const isCallback = location.pathname === '/callback';

  useEffect(() => {
    if (isCallback) {
      auth.signinRedirectCallback()
        .then(() => window.location.replace('/'))
        .catch(err => setError(err.message));
      return;
    }
    auth.getUser().then(setUser).catch(err => setError(err.message));
  }, [isCallback]);

  async function callApi(path) {
    try {
      setError('');
      const current = await auth.getUser();
      if (!current || current.expired) throw new Error('Please sign in again.');
      const res = await fetch(`http://127.0.0.1:8080${path}`, {
        headers: { Authorization: `Bearer ${current.access_token}` },
      });
      const text = await res.text();
      setResult(`${res.status}: ${text}`);
    } catch (err) { setError(err.message); }
  }

  if (isCallback) return <main><h1>Signing you in…</h1>{error && <p role="alert">{error}</p>}</main>;
  return <main>
    <h1>TrueNorth119</h1>
    <p>OAuth2 + OpenID Connect developer demo</p>
    {user && !user.expired ? <>
      <p>Signed in as: <strong>{user.profile?.sub}</strong></p>
      <button onClick={() => callApi('/api/me')}>Test secured API</button>
      <button onClick={() => callApi('/api/profile')}>Create / load MySQL profile</button>
      <button onClick={() => auth.signoutRedirect().catch(err => setError(err.message))}>Sign out</button>
      <pre>{result}</pre>
    </> : <button onClick={() => auth.signinRedirect().catch(err => setError(err.message))}>Sign in</button>}
    {error && <p role="alert">Error: {error}</p>}
  </main>;
}

createRoot(document.getElementById('root')).render(<App />);
