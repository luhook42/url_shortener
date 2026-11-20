import { useState } from "react";
import type { SubmitEvent } from "react";
import { signIn, type Session } from "../api/session";

interface Props {
  onSignedIn: (session: Session) => void;
}

function SignInForm({ onSignedIn }: Props) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: SubmitEvent<HTMLFormElement>) => {
    e.preventDefault();
    try {
      const session = await signIn(email, password);
      setPassword("");
      onSignedIn(session);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign-in failed");
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input type="email" autoComplete="username" placeholder="Email" required
        value={email} onChange={(e) => setEmail(e.target.value)} />
      <input type="password" autoComplete="current-password" placeholder="Password" required
        value={password} onChange={(e) => setPassword(e.target.value)} />
      <button type="submit">Sign in</button>
      {error && <div style={{ color: "crimson" }}>{error}</div>}
    </form>
  );
}

export default SignInForm;
