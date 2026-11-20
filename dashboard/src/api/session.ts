import { apiRequest, BASE_URL } from "./links";

export interface Session {
  email: string;
}

export function getSession(): Promise<Session> {
  return apiRequest<Session>(`${BASE_URL}/session`);
}

export function signIn(email: string, password: string): Promise<Session> {
  return apiRequest<Session>(`${BASE_URL}/session`, {
    method: "POST",
    body: new URLSearchParams({ email, password }),
  });
}

export function signOut(): Promise<void> {
  return apiRequest<void>(`${BASE_URL}/session`, { method: "DELETE" });
}
