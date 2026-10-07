import { useState } from "react";
import type { SubmitEvent } from "react";
import type { Link } from "../types/link";
import { updateLink } from "../api/links";

type Props = {
  link: Link;
  onLinkUpdated: (link: Link) => void;
};

const LinkRow = ({ link, onLinkUpdated }: Props) => {
  const [isEditing, setIsEditing] = useState(false);
  const [draftUrl, setDraftUrl] = useState(link.long_url);

  const startEditing = () => {
    setDraftUrl(link.long_url);
    setIsEditing(true);
  };

  const handleSubmit = async (e: SubmitEvent<HTMLFormElement>) => {
    e.preventDefault();
    try {
      const updated = await updateLink(link.short_code, draftUrl);
      onLinkUpdated(updated);
      setIsEditing(false);
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <div>
      <a href={`http://localhost:4567/${link.short_code}`}>{link.short_code}</a>
      {" → "}
      {isEditing ? (
        <form onSubmit={handleSubmit} style={{ display: "inline" }}>
          <input
            type="text"
            value={draftUrl}
            onChange={(e) => setDraftUrl(e.target.value)}
          />
          <button type="submit">Save</button>
          <button type="button" onClick={() => setIsEditing(false)}>
            Cancel
          </button>
        </form>
      ) : (
        <>
          {link.long_url} <button onClick={startEditing}>Edit</button>
        </>
      )}
    </div>
  );
};

export default LinkRow;
