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

  const handleSubmit = async (e: SubmitEvent<HTMLFormElement>) => {
    e.preventDefault();
    try {
      const newLink = await createLink(url);
      onLinkCreated(newLink);
      setUrl("");
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="text"
        value={url}
        onChange={(e) => setUrl(e.target.value)}
        placeholder="https://example.com"
      />
      <button type="submit">Shorten</button>
    </form>
  );
};

export default LinkForm;
