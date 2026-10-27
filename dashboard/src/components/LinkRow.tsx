import { useState } from "react";
import type { SubmitEvent } from "react";
import type { Link } from "../types/link";
import { BASE_URL, updateLink } from "../api/links";

type Props = {
  link: Link;
  onLinkUpdated: (link: Link) => void;
};

const LinkRow = ({ link, onLinkUpdated }: Props) => {
  const [isEditing, setIsEditing] = useState(false);
  const [draftUrl, setDraftUrl] = useState(link.long_url);
  const [error, setError] = useState<string | null>(null);

  const startEditing = () => {
    setDraftUrl(link.long_url);
    setError(null);
    setIsEditing(true);
  };

  const cancelEditing = () => {
    setError(null);
    setIsEditing(false);
  };

  const handleSubmit = async (e: SubmitEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    try {
      const updated = await updateLink(link.short_code, draftUrl);
      onLinkUpdated(updated);
      setIsEditing(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong");
    }
  };

  return (
    <div>
      <a href={`${BASE_URL}/${link.short_code}`}>{link.short_code}</a>
      {" → "}
      {isEditing ? (
        <form onSubmit={handleSubmit} style={{ display: "inline" }}>
          <input
            type="url"
            value={draftUrl}
            onChange={(e) => setDraftUrl(e.target.value)}
          />
          <button type="submit">Save</button>
          <button type="button" onClick={cancelEditing}>
            Cancel
          </button>
        </form>
      ) : (
        <>
          {link.long_url} <button onClick={startEditing}>Edit</button>
        </>
      )}
      {error && <div style={{ color: "crimson" }}>{error}</div>}
    </div>
  );
};

export default LinkRow;
