import type { Link } from "../types/link";
import LinkRow from "./LinkRow";

type Props = {
  links: Link[];
  onLinkUpdated: (link: Link) => void;
};

const LinkList = ({ links, onLinkUpdated }: Props) => {
  return (
    <div>
      {links.map((link) => (
        <LinkRow key={link.id} link={link} onLinkUpdated={onLinkUpdated} />
      ))}
    </div>
  );
};

export default LinkList;
