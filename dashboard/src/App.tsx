import "./App.css";
import LinkList from "./components/LinkList";
import LinkForm from "./components/LinkForm";
import SignInForm from "./components/SignInForm";
import { useEffect, useState } from "react";
import type { Link } from "./types/link";
import { ApiError, getLinks } from "./api/links";
import { getSession, signOut, type Session } from "./api/session";

function App() {
  const [links, setLinks] = useState<Link[]>([]);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [checking, setChecking] = useState(true);

  const fetchLinks = async () => {
    try {
      const respData = await getLinks();
      setLinks(respData);
      setLoadError(null);
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) return setSession(null);
      console.error(err);
      setLoadError(err instanceof Error ? err.message : "Failed to load links");
    }
  };

  const handleLinkCreated = (newLink: Link) => {
    setLinks((prevLinks) => [newLink, ...prevLinks]);
  };

  const handleLinkUpdated = (updated: Link) => {
    setLinks((prev) => prev.map((l) => (l.id === updated.id ? updated : l)));
  };

  const handleSignOut = async () => {
    await signOut();
    setSession(null);
    setLinks([]);
  };

  useEffect(() => {
    getSession()
      .then(setSession)
      .catch(() => setSession(null))
      .finally(() => setChecking(false));
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (session) fetchLinks();
  }, [session]);

  if (checking) return <p>Loading…</p>;
  if (!session) return <SignInForm onSignedIn={setSession} />;

  return (
    <div>
      <p>
        Signed in as {session.email} <button onClick={handleSignOut}>Sign out</button>
      </p>
      <LinkForm onLinkCreated={handleLinkCreated} />
      {loadError && (
        <div style={{ color: "crimson" }}>
          Could not load links: {loadError}
        </div>
      )}
      <LinkList links={links} onLinkUpdated={handleLinkUpdated} />
    </div>
  );
}

export default App;
