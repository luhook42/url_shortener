import { useState } from "react";
import type { SubmitEvent } from "react";
import type { Link } from "../types/link";
import { createLink } from "../api/links";

const LinkForm = ({
  onLinkCreated,
}: {
  onLinkCreated: (newLink: Link) => void;
}) => {
  const [url, setUrl] = useState("");
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: SubmitEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError(null);
    try {
      const newLink = await createLink(url);
      onLinkCreated(newLink);
      setUrl("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong");
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="url"
        required
        value={url}
        onChange={(e) => setUrl(e.target.value)}
        placeholder="https://example.com"
      />
      <button type="submit">Shorten</button>
      {error && <div style={{ color: "crimson" }}>{error}</div>}
    </form>
  );
};

export default LinkForm;
