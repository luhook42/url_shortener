import type { Link } from "../types/link";

const LinkList = ({ links }: { links: Link[] }) => {
  return (
    <div>
      {links.map((link) => (
        <div key={link.id}>
          <a href={`http://localhost:4567/${link.short_code}`}>
            {link.short_code}
          </a>
          {" → "}
          {link.long_url}
        </div>
      ))}
    </div>
  );
};

export default LinkList;
