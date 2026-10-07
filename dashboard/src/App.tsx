import "./App.css";
import LinkList from "./components/LinkList";
import LinkForm from "./components/LinkForm";
import { useEffect, useState } from "react";
import type { Link } from "./types/link";
import { getLinks } from "./api/links";

function App() {
  const [links, setLinks] = useState<Link[]>([]);

  const fetchLinks = async () => {
    try {
      const respData = await getLinks();
      setLinks(respData);
    } catch (err) {
      console.error(err);
    }
  };

  const handleLinkCreated = (newLink: Link) => {
    setLinks((prevLinks) => [newLink, ...prevLinks]);
  };

  const handleLinkUpdated = (updated: Link) => {
    setLinks((prev) => prev.map((l) => (l.id === updated.id ? updated : l)));
  };

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    fetchLinks();
  }, []);

  return (
    <div>
      <LinkForm onLinkCreated={handleLinkCreated} />
      <LinkList links={links} onLinkUpdated={handleLinkUpdated} />
    </div>
  );
}

export default App;
