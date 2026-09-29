import { useState, useEffect } from "react";

import { getLinks } from "../api/links";
import type { Link } from "../types/link";

const LinkList = () => {
  const [links, setLinks] = useState<Link[]>([]);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const respData = await getLinks();
        setLinks(respData);
      } catch (err) {
        console.error(err);
      }
    };
    fetchData();
  }, []);

  return (
    <div>
      {links.map((link) => (
        <div key={link.id}>{link.long_url}</div>
      ))}
    </div>
  );
};

export default LinkList;
