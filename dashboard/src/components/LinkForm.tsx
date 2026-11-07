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
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: SubmitEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (submitting) return;
    setError(null);
    setSubmitting(true);
    try {
      const newLink = await createLink(url);
      onLinkCreated(newLink);
      setUrl("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong");
    } finally {
      setSubmitting(false);
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
      <button type="submit" disabled={submitting}>
        Shorten
      </button>
      {error && <div style={{ color: "crimson" }}>{error}</div>}
    </form>
  );
};

export default LinkForm;
